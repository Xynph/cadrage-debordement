extends Node
## Banc en direct (revue FM27, idée 34) : bouton « Banc » dans la bande des commandes (à côté d'Équipe, Consignes,
## Réglages, Plus), menu déroulant comme dans FM (choix de Léo du 24/11/2026, il remplace la barre de ronds).
## Le bouton reste allumé tant que le menu est ouvert ; Échap ou un clic à côté le ferment. Fond anthracite satiné commun
## aux fenêtres du match. Un clic sur une ligne applique tout de suite : aucun bouton Confirmer.
## - Cris d'équipe : les cinq cris de la touche du moteur (commande `cri`), leur usure (3 points) et le cri en cours.
## - « À un joueur » : sous-liste à côté du menu, nos quinze en lignes, trois cris par joueur (commande `cri` avec
##   `joueur`). Le cri agit vraiment, avec du hasard (dist/match-pilotage.js, crierJoueur) : bien ou mal pris, on ne le
##   découvre qu'après coup (▲ / ▼, « — » s'il n'écoute plus). Aucun effet chiffré avant d'agir (principe d'incertitude).
## - Ajustements : raccourcis vers les consignes en direct du moteur (commande `set_consignes`) ; un ajustement allumé
##   se rééteint d'un clic (retour au cran neutre). « Permuter les ailes » : nos ailiers n° 11 et 14 échangent leurs
##   côtés au prochain arrêt de jeu (file `file_arret`, native/engine/match-arrets.cjs) ; « ⧗ » tant qu'il attend.
## Le menu et la sous-liste ouverts sont mis à jour EN PLACE pendant le match (jamais recréés à chaque minute).
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
## Ardoise claire (teinte D) commune aux petites fenêtres du direct : fenêtre d'un joueur, consignes, cris à un joueur.
const MenuJoueur = preload("res://ui/contextual/match_menu_joueur.gd")
const PAL: Dictionary = MenuJoueur.PAL

const NOM := "MatchFmBanc"

## Icônes propres à la barre (tracés 24×24, trait).
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
	"ailes": "M4 8h14l-3-3 M18 8l-3 3 M20 16H6l3-3 M6 16l3 3 M2 3v18 M22 3v18",
	"pouce": "M7 11v9H4v-9z M7 11l4-7c1.5 0 2.5 1 2 3l-1 3h6a2 2 0 0 1 2 2l-2 7a2 2 0 0 1-2 1H7",
	"haut": "M6 14l6-6 6 6 M6 20l6-6 6 6",
	"calme": "M12 3v18 M4.2 7.5l15.6 9 M4.2 16.5l15.6-9",
	"bouclier": "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z M9 12l2 2 4-4",
	"reveil": "M12 6a7 7 0 1 1 0 14 7 7 0 0 1 0-14z M12 10v3h3 M4 4l3 3 M20 4l-3 3",
}

## Ajustements : [id, libellé, icône, axe, valeur, famille, tendances [[mot, sens]], mot court].
const AJUSTEMENTS := [
	["pied", "Jouer au pied", "pied", "piedJeu", "plus", "attaque", [["occupation", 1], ["possession", -1]], "Au pied"],
	["garder", "Garder le ballon", "main", "piedJeu", "moins", "attaque", [["possession", 1], ["camp", -1]], "Garder"],
	["accelerer", "Accélérer", "vite", "rythme", "rapide", "attaque", [["rythme", 1], ["énergie", -1]], "Accélérer"],
	["souffler", "Souffler un peu", "souffle", "rythme", "lent", "attaque", [["énergie", 1], ["rythme", -1]], "Souffler"],
	["relancer", "Relancer de loin", "relance", "relance", "relancer", "attaque", [["mètres", 1], ["pertes", -1]], "Relancer"],
	["contester", "Contester les rucks", "ruck", "rucks", "agressive", "defense", [["ballons volés", 1], ["pénalités", -1]], "Contester"],
	["zero", "Zéro faute", "sifflet", "discipline", "stricte", "defense", [["discipline", 1], ["plaquages", -1]], "Zéro faute"],
	["pousser", "Pousser en mêlée", "melee", "melee", "pousser", "conquete", [["pénalités obtenues", 1], ["sifflets", -1]], "Pousser"],
	["porte", "Ballon porté", "porte", "maul", "souvent", "conquete", [["essais de près", 1]], "Porté"],
	["aile", "Viser l'aile faible", "cible", "cible", "aile", "conquete", [["franchissements", 1]], "Aile faible"],
	["montre", "Jouer la montre", "montre", "finDeMatch", "montre", "fin", [["temps", 1], ["points", -1]], "La montre"],
	["tout_tenter", "Tout tenter", "tout", "finDeMatch", "tout", "fin", [["points", 1], ["contres", -1]], "Tout tenter"],
]
const FAMILLES := {"attaque": Charte.INTENSIF, "defense": Charte.PERTE, "conquete": Charte.MORAL, "fin": Charte.CONFIANCE}
## Cris d'équipe du moteur : id → [icône, couleur, mot court].
const CRIS := {
	"encourager": ["pouce", Charte.CONDITION, "Encourager"],
	"exiger": ["haut", Charte.INTENSIF, "Exiger"],
	"calmer": ["calme", Charte.MORAL, "Calmer"],
	"defense": ["bouclier", Charte.REPOS, "Défense"],
	"toutDonner": ["tout", Charte.PERTE, "Tout donner"],
}
## Cris à un joueur (moteur : CRIS_JOUEUR) : [id, libellé, icône, couleur].
const CRIS_JOUEUR := [["bravo", "Bien joué", "pouce", Charte.CONDITION], ["niveau", "Hausse le niveau", "haut", Charte.INTENSIF], ["reveil", "Réveille-toi", "reveil", Charte.PERTE]]

var between: Control
## Bouton « Banc » de la bande des commandes.
var bouton_banc: Button
## Calque du menu ouvert (clic à côté = fermer) ; il porte le menu déroulant et la sous-liste « À un joueur ».
var _calque: Control
var _deroulant: PanelContainer
var _menu: PanelContainer
var _cle := ""

## Pose le bouton « Banc » dans la bande des commandes, juste avant « Consignes ».
static func poser(hote: Control, barre: Control, _page: Control) -> Node:
	var banc := new()
	banc.name = NOM
	banc.between = hote
	hote.add_child(banc)
	var b: Button = hote._lien("Banc", banc.basculer_menu, "MatchBetweenBench")
	b.add_theme_font_size_override("font_size", hote.fpx(22 * float(hote.get_script().get_script_constant_map().get("BARRE_HAUT", 1.28))))
	b.tooltip_text = "Cris, ajustements, permuter les ailes"
	b.set_meta("ouvert", false)
	banc.bouton_banc = b
	barre.add_child(b)
	var consignes: Variant = hote.get("lien_consignes")
	if consignes is Control and (consignes as Control).get_parent() == barre: barre.move_child(b, (consignes as Control).get_index())
	# L'écran se reconstruit (taille, échelle) : le menu ouvert (et sa sous-liste) revient.
	if bool(hote.get_meta("fm_menu", false)): banc.call_deferred("ouvrir_menu", bool(hote.get_meta("fm_joueurs", false)))
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
	var a: Variant = _cris().get("actif")
	return a if a is Dictionary else {}

## Réactions aux cris individuels (après coup) : {id joueur: {cri, minute, sens, enCours}}.
func _reactions() -> Dictionary:
	var ind: Variant = _cris().get("individuels")
	var j: Variant = (ind as Dictionary).get("joueurs") if ind is Dictionary else null
	return j if j is Dictionary else {}

## Permutation des ailes : {permutees, attente} (file du prochain arrêt).
func _ailes() -> Dictionary:
	var a: Variant = _pilotage().get("arrets")
	var e: Variant = (a as Dictionary).get("ailes") if a is Dictionary else null
	return e if e is Dictionary else {}

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

func crier(id: String) -> void:
	var o := _cri_option(id)
	if not o.is_empty() and not bool(o.get("disponible", true)): return
	var app: Object = between._app()
	if app != null: app._command("cri", {"id": id})
	rafraichir(true)

func crier_joueur(id_joueur: String, cri: String) -> void:
	var app: Object = between._app()
	if app != null: app._command("cri", {"id": cri, "joueur": id_joueur})
	rafraichir(true)

func permuter_ailes() -> void:
	var app: Object = between._app()
	if app != null: app._command("file_arret", {"action": "ajouter", "change": {"type": "ailes"}})
	rafraichir(true)

## Appelé à chaque image du modèle : met à jour EN PLACE les lignes du menu et la sous-liste « À un joueur » ouverts.
func rafraichir(force: bool = false) -> void:
	var envois := _envois()
	var consignes: Variant = _pilotage().get("consignes")
	if consignes is Dictionary:
		for axe: Variant in envois.keys():
			if str((consignes as Dictionary).get(str(axe), "")) == str(envois[axe]): envois.erase(axe)
	if is_instance_valid(_menu): _maj_joueurs()
	var cle := JSON.stringify([_pilotage().get("consignes"), _cris(), _ailes(), envois, is_instance_valid(_menu)])
	if cle == _cle and not force: return
	_cle = cle
	if is_instance_valid(_deroulant): _maj_lignes()

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

## Rond coloré portant une icône (allumé : aplat de la couleur, icône sombre ; éteint : voile de la couleur). `attente` :
## liseré pointillé de la couleur (changement demandé, pas encore en place).
## `vif` : rond éteint mieux lisible sur l'anthracite des fenêtres (voile plus dense, liseré, icône éclaircie).
func _rond(id: String, couleur: Color, cote: float, allume: bool, attente: bool = false, vif: bool = false) -> PanelContainer:
	var rond := PanelContainer.new()
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = couleur if allume else Color(couleur, 0.26 if vif else 0.16)
	if vif and not allume and not attente:
		st.border_color = Color(couleur, 0.55)
		st.set_border_width_all(maxi(1, px(1.5)))
	st.set_corner_radius_all(Charte.RAYON_PILULE)
	st.anti_aliasing = true
	if attente:
		st.border_color = couleur
		st.set_border_width_all(maxi(2, px(3)))
	var m := px(cote * 0.2)
	st.content_margin_left = m
	st.content_margin_right = m
	st.content_margin_top = m
	st.content_margin_bottom = m
	rond.add_theme_stylebox_override("panel", st)
	rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rond.add_child(_icone(id, Charte.ENCRE if allume else (couleur.lightened(0.3) if vif else couleur), cote * 0.6))
	return rond

func _texte(t: String, taille: float, couleur: Color, titre: bool = false) -> Label:
	var l: Label = between._texte(t, taille, couleur, false, titre)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _vide() -> Control:
	var v := Control.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v

# ------------------------------------------------------------------ menu déroulant « Banc »

func menu_ouvert() -> bool: return is_instance_valid(_deroulant)

func basculer_menu() -> void:
	if menu_ouvert(): fermer_menu()
	else: ouvrir_menu()

## Menu sous le bouton « Banc » : à gauche les cris d'équipe, « À un joueur », permuter les ailes ; à droite les
## ajustements. Le bouton reste allumé tant qu'il est ouvert.
func ouvrir_menu(avec_joueurs: bool = false) -> void:
	if menu_ouvert():
		if avec_joueurs and not is_instance_valid(_menu): ouvrir_joueurs()
		return
	_calque = Control.new()
	_calque.name = "FmBancMenu"
	_calque.mouse_filter = Control.MOUSE_FILTER_STOP
	_calque.z_index = 60
	_calque.gui_input.connect(func(e: InputEvent):
		var clic := e as InputEventMouseButton
		if clic != null and clic.pressed: fermer_menu())
	between.add_child(_calque)
	_calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	PetiteFenetre.enregistrer(_calque, fermer_menu)
	between.set_meta("fm_menu", true)
	_deroulant = PanelContainer.new()
	_deroulant.name = "FmBancDeroulant"
	_deroulant.add_theme_stylebox_override("panel", MenuJoueur.style_ardoise(px(14)))
	_deroulant.mouse_filter = Control.MOUSE_FILTER_STOP
	_calque.add_child(_deroulant)
	var colonnes := HBoxContainer.new()
	colonnes.add_theme_constant_override("separation", px(18))
	_deroulant.add_child(colonnes)
	var gauche := _colonne_menu(colonnes, "CRIS")
	for id: String in CRIS: gauche.add_child(_ligne_menu("FmCri_" + id, crier.bind(id)))
	gauche.add_child(_ligne_menu("FmBancJoueur", ouvrir_joueurs))
	gauche.add_child(_filet())
	gauche.add_child(_ligne_menu("FmAjust_ailes", permuter_ailes))
	var droite := _colonne_menu(colonnes, "AJUSTEMENTS")
	for aj: Array in AJUSTEMENTS: droite.add_child(_ligne_menu("FmAjust_" + str(aj[0]), basculer.bind(aj)))
	_maj_lignes(true)
	_allumer(true)
	_deroulant.visible = false
	_placer_menu()
	if avec_joueurs: ouvrir_joueurs()

func fermer_menu() -> void:
	between.set_meta("fm_menu", false)
	between.set_meta("fm_joueurs", false)
	if is_instance_valid(_calque): _calque.queue_free()
	_calque = null
	_deroulant = null
	_menu = null
	_liste = null
	_allumer(false)

## Bouton « Banc » allumé (fond éclairé, liseré or, texte or) tant que le menu est ouvert.
func _allumer(ouvert: bool) -> void:
	if not is_instance_valid(bouton_banc): return
	bouton_banc.set_meta("ouvert", ouvert)
	for etat: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		if not ouvert:
			bouton_banc.remove_theme_stylebox_override(etat)
			continue
		var st := StyleBoxFlat.new()
		st.bg_color = Charte.PANNEAU_3
		st.border_color = Charte.OR
		st.set_border_width_all(maxi(1, px(2)))
		st.set_corner_radius_all(Charte.RAYON_PETIT)
		st.content_margin_left = px(10)
		st.content_margin_right = px(10)
		bouton_banc.add_theme_stylebox_override(etat, st)
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		if ouvert: bouton_banc.add_theme_color_override(k, Charte.OR)
		else: bouton_banc.remove_theme_color_override(k)

## Le menu s'ouvre juste sous le bouton, aligné sur son bord gauche (sur son bord droit s'il sortirait de l'écran).
func _placer_menu(essais: int = 0) -> void:
	if not is_instance_valid(_deroulant) or not is_inside_tree(): return
	var r := bouton_banc.get_global_rect() if is_instance_valid(bouton_banc) and bouton_banc.is_visible_in_tree() else Rect2()
	if r.size.x <= 0.0:
		if essais < 12: get_tree().process_frame.connect(_placer_menu.bind(essais + 1), CONNECT_ONE_SHOT)
		else: _deroulant.visible = true
		return
	_deroulant.size = _deroulant.get_combined_minimum_size()
	var ecran := between.get_viewport_rect().size
	var pos := Vector2(r.position.x, r.end.y + px(6))
	if pos.x + _deroulant.size.x > ecran.x - px(16): pos.x = r.end.x - _deroulant.size.x
	pos.x = clampf(pos.x, px(16), maxf(px(16), ecran.x - _deroulant.size.x - px(16)))
	_deroulant.position = pos - between.get_global_rect().position
	_deroulant.visible = true
	if is_instance_valid(_menu): _placer_joueurs()
	# La bande se pose sur une ou deux images (écran reconstruit) : on suit le bouton.
	if essais < 2: get_tree().process_frame.connect(_placer_menu.bind(essais + 1), CONNECT_ONE_SHOT)

func _colonne_menu(parent: Control, titre: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", px(2))
	parent.add_child(col)
	var t := _texte(titre, 18, PAL.encre2, true)
	t.custom_minimum_size.y = px(30)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(t)
	return col

func _filet() -> ColorRect:
	var f := ColorRect.new()
	f.color = PAL.filet
	f.custom_minimum_size.y = maxi(1, px(1))
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f

## Ligne du menu : un bouton qui reste le même pendant tout le match ; son contenu suit l'état (_maj_lignes).
func _ligne_menu(nom: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = nom
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(px(280), px(44))
	for etat: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = PAL.case if etat in ["hover", "hover_pressed", "pressed"] else Color(0, 0, 0, 0)
		if etat == "focus":
			st.border_color = Charte.OR
			st.set_border_width_all(2)
		st.set_corner_radius_all(Charte.RAYON_PETIT)
		b.add_theme_stylebox_override(etat, st)
	b.pressed.connect(action)
	return b

## État d'une ligne : [icône, couleur, mot, allumé, disponible, attente, marque à droite, usure (-1 : aucune), infobulle].
func _etat_ligne(nom: String) -> Array:
	if nom.begins_with("FmCri_"):
		var id := nom.trim_prefix("FmCri_")
		var def: Array = CRIS[id]
		var o := _cri_option(id)
		var actif := _cri_actif()
		var en_cours := str(actif.get("id", "")) == id
		return [str(def[0]), def[1], str(def[2]), en_cours, o.is_empty() or bool(o.get("disponible", true)), false,
			("→ %d′" % int(actif.get("jusqua", 0))) if en_cours else "", float(o.get("usure", 0.0)), str(o.get("label", def[2]))]
	if nom == "FmBancJoueur":
		var ouvert := is_instance_valid(_menu)
		return ["people", Charte.OR if ouvert else Charte.IVOIRE_2, "À un joueur", ouvert, true, false, "‹" if ouvert else "›", -1.0, "Crier à un joueur"]
	if nom == "FmAjust_ailes":
		var ailes := _ailes()
		var attente := bool(ailes.get("attente", false))
		return ["ailes", Charte.MORAL, "Permuter les ailes", bool(ailes.get("permutees", false)) and not attente, true, attente, "⧗" if attente else "", -1.0,
			"Nos n° 11 et 14 changent de côté au prochain arrêt de jeu"]
	for aj: Array in AJUSTEMENTS:
		if nom == "FmAjust_" + str(aj[0]):
			var effets := "\n".join((aj[6] as Array).map(func(e: Array): return ("▲ " if int(e[1]) > 0 else "▼ ") + str(e[0])))
			return [str(aj[2]), FAMILLES[str(aj[5])], str(aj[1]), ajustement_actif(aj), true, false, "", -1.0, effets]
	return ["", Charte.IVOIRE_2, nom, false, true, false, "", -1.0, ""]

## Met à jour les lignes du menu EN PLACE : seul le contenu d'une ligne dont l'état change est refait.
func _maj_lignes(tout: bool = false) -> void:
	if not is_instance_valid(_deroulant): return
	for n: Node in _deroulant.find_children("Fm*", "Button", true, false):
		var b := n as Button
		var e := _etat_ligne(str(b.name))
		var cle := JSON.stringify(e)
		if not tout and str(b.get_meta("etat", "")) == cle: continue
		b.set_meta("etat", cle)
		b.set_meta("allume", bool(e[3]))
		b.set_meta("ouvert", bool(e[3]) if b.name == "FmBancJoueur" else false)
		b.disabled = not bool(e[4])
		b.tooltip_text = str(e[8])
		for vieux in b.get_children():
			b.remove_child(vieux)
			vieux.queue_free()
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", px(10))
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = px(6)
		h.offset_right = -px(8)
		b.add_child(h)
		var couleur: Color = e[1] if bool(e[4]) else PAL.encre3
		var rond := _rond(str(e[0]), couleur, 32, bool(e[3]), bool(e[5]), true)
		h.add_child(rond)
		var mot := _texte(str(e[2]), 18, (couleur.lightened(0.25) if bool(e[3]) else PAL.encre) if bool(e[4]) else PAL.encre3)
		mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(mot)
		if float(e[7]) >= 0.0: h.add_child(_usure(float(e[7]), bool(e[3]), false))
		if not str(e[6]).is_empty():
			var marque := _texte(str(e[6]), 16, couleur if bool(e[3]) or bool(e[5]) else PAL.encre2, true)
			marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(marque)

# ------------------------------------------------------------------ sous-liste « À un joueur »

func fermer_joueurs() -> void:
	between.set_meta("fm_joueurs", false)
	if is_instance_valid(_menu): _menu.queue_free()
	_menu = null
	_liste = null
	_maj_lignes()

## Sous-liste à côté du menu (à sa gauche, alignée sur son haut) : nos quinze, trois cris chacun.
func ouvrir_joueurs() -> void:
	if not menu_ouvert():
		ouvrir_menu(true)
		return
	if is_instance_valid(_menu):
		fermer_joueurs()
		return
	_menu = PanelContainer.new()
	_menu.name = "FmBancMenuPanneau"
	_menu.add_theme_stylebox_override("panel", MenuJoueur.style_ardoise(px(16)))
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_calque.add_child(_menu)
	between.set_meta("fm_joueurs", true)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", px(4))
	_menu.add_child(col)
	var tete := HBoxContainer.new()
	col.add_child(tete)
	tete.add_child(_texte("CRIS À UN JOUEUR", 24, PAL.encre, true))
	tete.add_child(_vide())
	for c: Array in CRIS_JOUEUR:
		var entete := _icone(str(c[2]), c[3], 26)
		entete.tooltip_text = str(c[1])
		entete.mouse_filter = Control.MOUSE_FILTER_PASS
		tete.add_child(entete)
	var fermer := Button.new()
	fermer.name = "FmBancMenuFermer"
	fermer.flat = true
	fermer.text = "✕"
	fermer.focus_mode = Control.FOCUS_ALL
	fermer.add_theme_font_size_override("font_size", between.fpx(24))
	fermer.add_theme_color_override("font_color", PAL.encre2)
	fermer.add_theme_color_override("font_hover_color", PAL.encre)
	fermer.pressed.connect(fermer_joueurs)
	tete.add_child(fermer)
	_liste_joueurs(col)
	_menu.custom_minimum_size.x = px(560)
	_maj_lignes()
	_placer_joueurs()

func _placer_joueurs() -> void:
	if not is_instance_valid(_menu) or not is_instance_valid(_deroulant): return
	_menu.size = _menu.get_combined_minimum_size()
	var ecran := between.get_viewport_rect().size
	var d := _deroulant.get_global_rect()
	var pos := Vector2(d.position.x - _menu.size.x - px(8), d.position.y)
	if pos.x < px(16): pos.x = d.end.x + px(8)
	pos.x = clampf(pos.x, px(16), maxf(px(16), ecran.x - _menu.size.x - px(16)))
	pos.y = clampf(pos.y, px(16), maxf(px(16), ecran.y - _menu.size.y - px(16)))
	_menu.position = pos - between.get_global_rect().position

## Nos quinze : numéro, nom, moral en direct, trois cris en ronds, puis la réaction au dernier cri (après coup).
var _liste: VBoxContainer
var _cle_liste := ""

func _liste_joueurs(col: VBoxContainer) -> void:
	var defile := ScrollContainer.new()
	defile.name = "FmBancMenuDefile"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.custom_minimum_size.y = px(600)
	col.add_child(defile)
	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("separation", px(2))
	defile.add_child(_liste)
	_cle_liste = ""
	_maj_joueurs()

## Nos quinze, mis à jour EN PLACE : une ligne par poste, créée une fois ; seuls le nom, le moral, l'état des ronds et la
## réaction changent (le joueur du poste est relu au clic, un remplaçant entré prend la ligne).
func _maj_joueurs() -> void:
	if not is_instance_valid(_liste): return
	var d: Variant = between.get("_dernier")
	var live: Dictionary = d[1] if d is Array and (d as Array).size() > 1 and d[1] is Dictionary else {}
	var lineup: Array = live.get("lineup", []) if live.get("lineup") is Array else []
	var reactions := _reactions()
	var morals := lineup.map(func(j: Variant) -> Dictionary: return between.moral_joueur(_pilotage(), str(j.get("id", ""))) if j is Dictionary else {})
	var cle := JSON.stringify([lineup.map(func(j: Variant) -> Array: return [str(j.get("id", "")), str(j.get("name", ""))] if j is Dictionary else []), morals, reactions])
	if cle == _cle_liste: return
	_cle_liste = cle
	var n := 0
	for j: Variant in lineup:
		n += 1
		var ligne := _liste.get_node_or_null("FmCriJoueur_%d" % n) as HBoxContainer
		if not j is Dictionary:
			if ligne != null: ligne.visible = false
			continue
		if ligne == null:
			ligne = _ligne_joueur(n)
			_liste.add_child(ligne)
		ligne.visible = true
		var id := str(j.get("id", ""))
		ligne.set_meta("id", id)
		var nom := ligne.get_node("FmCriNom") as Label
		if nom.get_meta("nom", "") != str(j.get("name", "")):
			nom.set_meta("nom", str(j.get("name", "")))
			nom.text = str(j.get("name", ""))
			nom.remove_theme_font_size_override("font_size")
			nom.add_theme_font_size_override("font_size", between.fpx(18))
			_nom_qui_tient(nom, px(160))
		var moral: Dictionary = morals[n - 1]
		var pastille := ligne.get_node("FmCriMoral") as PanelContainer
		var etiquette := pastille.get_child(0) as Label
		if not moral.is_empty():
			var teinte: Color = between.teinte_moral(str(moral.get("cle", "")))
			pastille.add_theme_stylebox_override("panel", Charte.style_pilule(Color(teinte, 0.16), Color.TRANSPARENT, px(10), px(2)))
			etiquette.text = str(moral.get("label", ""))
			etiquette.add_theme_color_override("font_color", teinte)
		else:
			pastille.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			etiquette.text = ""
		var vu: Dictionary = reactions.get(id, {}) if reactions.get(id) is Dictionary else {}
		var en_cours := bool(vu.get("enCours", false))
		for c: Array in CRIS_JOUEUR:
			var b := ligne.get_node("FmCriJoueur_%d_%s" % [n, str(c[0])]) as Button
			var ici := en_cours and str(vu.get("cri", "")) == str(c[0])
			if b.get_meta("allume", null) == ici: continue
			b.set_meta("allume", ici)
			for e in b.get_children():
				b.remove_child(e)
				e.queue_free()
			var rond := _rond(str(c[2]), c[3], 36, ici, false, true)
			rond.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			b.add_child(rond)
		var reaction := ligne.get_node("FmCriReactionBox") as HBoxContainer
		for e in reaction.get_children():
			reaction.remove_child(e)
			e.queue_free()
		_reaction(vu, reaction)
	for k in range(n + 1, _liste.get_child_count() + 1):
		var reste := _liste.get_node_or_null("FmCriJoueur_%d" % k) as Control
		if reste != null: reste.visible = false

## Ligne vide d'un poste (numéro, nom, moral, trois cris, réaction) ; `_maj_joueurs` la remplit.
func _ligne_joueur(n: int) -> HBoxContainer:
	var ligne := HBoxContainer.new()
	ligne.name = "FmCriJoueur_%d" % n
	ligne.add_theme_constant_override("separation", px(5))
	ligne.custom_minimum_size.y = px(44)
	var num := _texte(str(n), 18, PAL.encre2, true)
	num.custom_minimum_size.x = px(26)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(num)
	var nom := _texte("", 18, PAL.encre)
	nom.name = "FmCriNom"
	nom.custom_minimum_size.x = px(160)
	nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(nom)
	var pastille := PanelContainer.new()
	pastille.name = "FmCriMoral"
	pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastille.custom_minimum_size.x = px(88)
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pastille.add_child(_texte("", 15, PAL.encre2))
	ligne.add_child(pastille)
	ligne.add_child(_vide())
	for c: Array in CRIS_JOUEUR:
		var b := Button.new()
		b.name = "FmCriJoueur_%d_%s" % [n, str(c[0])]
		b.flat = true
		b.tooltip_text = str(c[1])
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = Vector2(px(38), px(40))
		var id_c := str(c[0])
		b.pressed.connect(func(): crier_joueur(str(ligne.get_meta("id", "")), id_c))
		ligne.add_child(b)
	var reaction := HBoxContainer.new()
	reaction.name = "FmCriReactionBox"
	reaction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reaction.custom_minimum_size.x = px(50)
	reaction.add_theme_constant_override("separation", px(4))
	reaction.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(reaction)
	return ligne

## Nom jamais coupé (Léo, 23/11) : nom complet s'il tient, sinon prénom en initiale (« J.-C. ROYER »), sinon police
## légèrement réduite (12 px au plus bas).
func _nom_qui_tient(etiquette: Label, largeur: float) -> void:
	var police := etiquette.get_theme_font("font")
	var taille := etiquette.get_theme_font_size("font_size")
	var largeur_de := func(t: String, s: int) -> float: return police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	if largeur_de.call(etiquette.text, taille) <= largeur: return
	etiquette.text = nom_court(etiquette.text)
	while taille > 12 and largeur_de.call(etiquette.text, taille) > largeur: taille -= 1
	etiquette.add_theme_font_size_override("font_size", taille)

## « Jean-Charles ROYER » → « J.-C. ROYER » ; « Giacomo PELLEGRINI » → « G. PELLEGRINI ».
static func nom_court(nom: String) -> String:
	var mots := nom.strip_edges().split(" ", false)
	if mots.size() < 2: return nom
	var initiales: Array[String] = []
	for partie: String in mots[0].split("-", false): initiales.append(partie.left(1) + ".")
	return "%s %s" % ["-".join(initiales), " ".join(mots.slice(1))]

## Réaction au dernier cri, découverte après coup : ▲ bien pris (vert), ▼ mal pris (rouge), « — » il n'écoute plus ;
## la minute du cri en petit. Rien tant qu'on ne lui a rien dit.
func _reaction(vu: Dictionary, h: HBoxContainer) -> void:
	if vu.is_empty(): return
	var sens := int(vu.get("sens", 0))
	var couleur: Color = Charte.GAIN if sens > 0 else Charte.PERTE if sens < 0 else PAL.encre3
	var fleche := _texte("▲" if sens > 0 else "▼" if sens < 0 else "—", 20, couleur)
	fleche.name = "FmCriReaction"
	h.add_child(fleche)
	var minute := _texte("%d′" % int(vu.get("minute", 0)), 15, PAL.encre if bool(vu.get("enCours", false)) else PAL.encre3)
	minute.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(minute)


## Usure d'un cri d'équipe en trois points (plein : intact ; à moitié ; vide : ils n'écoutent plus).
func _usure(usure: float, allume: bool, vertical: bool) -> Control:
	var h: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", px(3))
	var restants := 3 if usure <= 0.0 else 2 if usure <= 0.5 else 0
	for i in 3:
		var point := ColorRect.new()
		point.custom_minimum_size = Vector2(px(5), px(5))
		point.color = Charte.IVOIRE_2 if i < restants else Charte.FILET
		point.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(point)
	h.modulate.a = 0.5 if allume else 1.0
	return h
