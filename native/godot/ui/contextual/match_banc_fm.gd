extends Node
## Barre du banc (revue FM27, idée 34, choix B de Léo du 23/11/2026) : toujours visible au-dessus du tableau de bord du
## direct (match_between.gd), un rond par cri et par ajustement. Un clic choisit et applique : aucun bouton Confirmer.
## - Cris d'équipe : les cinq cris de la touche du moteur (commande `cri`), leur usure (3 points) et le cri en cours.
## - « À un joueur » : petite fenêtre, nos quinze en lignes, trois cris par joueur (commande `cri` avec `joueur`). Le
##   cri agit vraiment, avec du hasard (dist/match-pilotage.js, crierJoueur) : bien ou mal pris, on ne le découvre
##   qu'après coup (▲ / ▼, « — » s'il n'écoute plus). Aucun effet chiffré avant d'agir (principe d'incertitude).
## - Ajustements : raccourcis vers les consignes en direct du moteur (commande `set_consignes`) ; un ajustement allumé
##   se rééteint d'un clic (retour au cran neutre). « Permuter les ailes » : nos ailiers n° 11 et 14 échangent leurs
##   côtés au prochain arrêt de jeu (file `file_arret`, native/engine/match-arrets.cjs) ; « ⧗ » tant qu'il attend.
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
var barre_b: PanelContainer
var _menu: Control
var _cle := ""
var _ancre := Rect2()

## Pose la barre du banc en tête de page du tableau de bord.
static func poser(hote: Control, _barre: Control, page: Control) -> Node:
	var banc := new()
	banc.name = NOM
	banc.between = hote
	hote.add_child(banc)
	banc._barre_b(page)
	# L'écran se reconstruit (taille, échelle) : la fenêtre « À un joueur » ouverte revient.
	if bool(hote.get_meta("fm_joueurs", false)): banc.call_deferred("ouvrir_joueurs")
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

## Appelé à chaque image du modèle : remet à jour les états allumés et la fenêtre « À un joueur » ouverte.
func rafraichir(force: bool = false) -> void:
	var envois := _envois()
	var consignes: Variant = _pilotage().get("consignes")
	if consignes is Dictionary:
		for axe: Variant in envois.keys():
			if str((consignes as Dictionary).get(str(axe), "")) == str(envois[axe]): envois.erase(axe)
	var cle := JSON.stringify([_pilotage().get("consignes"), _cris(), _ailes(), envois, _minute() if is_instance_valid(_menu) else 0])
	if cle == _cle and not force: return
	_cle = cle
	if is_instance_valid(barre_b): _remplir_b()
	if is_instance_valid(_menu): _remplir_joueurs()

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

# ------------------------------------------------------------------ fenêtre « À un joueur »

func fermer_joueurs() -> void:
	between.set_meta("fm_joueurs", false)
	if is_instance_valid(_menu): _menu.queue_free()
	_menu = null
	if is_instance_valid(barre_b): _remplir_b()

## Petite fenêtre sous la barre : un calque qui ferme au clic à côté (Échap, ✕), la liste en panneau de la charte.
func ouvrir_joueurs() -> void:
	if is_instance_valid(_menu):
		fermer_joueurs()
		return
	var calque := Control.new()
	calque.name = "FmBancMenu"
	calque.mouse_filter = Control.MOUSE_FILTER_STOP
	calque.z_index = 60
	calque.gui_input.connect(func(e: InputEvent):
		var clic := e as InputEventMouseButton
		if clic != null and clic.pressed: fermer_joueurs())
	between.add_child(calque)
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu = calque
	between.set_meta("fm_joueurs", true)
	PetiteFenetre.enregistrer(calque, fermer_joueurs)
	_remplir_joueurs()
	if is_instance_valid(barre_b): _remplir_b()

func _remplir_joueurs() -> void:
	for e in _menu.get_children():
		_menu.remove_child(e)
		e.queue_free()
	var panneau := PanelContainer.new()
	panneau.name = "FmBancMenuPanneau"
	# Même cadre que la fenêtre d'un joueur (match_menu_joueur.gd) : fond ardoise claire, liseré, ombre portée.
	var st := MenuJoueur.style_ardoise(px(16))
	panneau.add_theme_stylebox_override("panel", st)
	panneau.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.add_child(panneau)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", px(4))
	panneau.add_child(col)
	var tete := HBoxContainer.new()
	col.add_child(tete)
	tete.add_child(_texte("CRIS À UN JOUEUR", 26, PAL.encre, true))
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
	panneau.custom_minimum_size.x = px(760)
	panneau.reset_size()
	panneau.visible = false
	_placer(panneau)

## La liste s'ouvre juste sous le rond « À un joueur » (accrochée à lui), sans sortir de l'écran.
func _placer(panneau: Control, essais: int = 0, suivis: int = 3) -> void:
	if not is_instance_valid(panneau) or not is_instance_valid(between) or not is_inside_tree(): return
	var ancre := Rect2()
	if is_instance_valid(barre_b):
		for n: Node in barre_b.find_children("FmBancJoueur", "Button", true, false):
			var r := (n as Control).get_global_rect()
			if r.size.x > 0.0 and not n.is_queued_for_deletion(): ancre = r
	if ancre.size.x <= 0.0: ancre = _ancre
	if ancre.size.x <= 0.0:
		# Écran tout juste reconstruit : la barre n'est pas encore posée, on réessaie à l'image suivante.
		if essais < 12: get_tree().process_frame.connect(_placer.bind(panneau, essais + 1, suivis), CONNECT_ONE_SHOT)
		else: panneau.visible = true
		return
	_ancre = ancre
	var largeur := panneau.size.x
	var ecran := between.get_viewport_rect().size
	var pos := Vector2(ancre.position.x, ancre.end.y + px(6))
	pos.x = clampf(pos.x, px(16), ecran.x - largeur - px(16))
	pos.y = minf(pos.y, maxf(px(16), ecran.y - panneau.size.y - px(16)))
	panneau.position = pos - between.get_global_rect().position
	# La barre se pose sur une ou deux images (écran reconstruit) : on suit le rond, la liste paraît une fois posée.
	if suivis > 0: get_tree().process_frame.connect(_placer.bind(panneau, essais, suivis - 1), CONNECT_ONE_SHOT)
	if suivis < 3: panneau.visible = true

## Nos quinze : numéro, nom, moral en direct, trois cris en ronds, puis la réaction au dernier cri (après coup).
func _liste_joueurs(col: VBoxContainer) -> void:
	var d: Variant = between.get("_dernier")
	var live: Dictionary = d[1] if d is Array and (d as Array).size() > 1 and d[1] is Dictionary else {}
	var reactions := _reactions()
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
		var num := _texte(str(n), 20, PAL.encre2, true)
		num.custom_minimum_size.x = px(30)
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(num)
		var nom := _texte(str(j.get("name", "")), 20, PAL.encre)
		nom.custom_minimum_size.x = px(230)
		nom.clip_text = true
		nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(nom)
		var moral: Dictionary = between.moral_joueur(_pilotage(), id)
		var pastille := PanelContainer.new()
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pastille.custom_minimum_size.x = px(120)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not moral.is_empty():
			var teinte: Color = between.teinte_moral(str(moral.get("cle", "")))
			pastille.add_theme_stylebox_override("panel", Charte.style_pilule(Color(teinte, 0.16), Color.TRANSPARENT, px(10), px(2)))
			pastille.add_child(_texte(str(moral.get("label", "")), 15, teinte))
		else:
			pastille.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		ligne.add_child(pastille)
		ligne.add_child(_vide())
		var vu: Dictionary = reactions.get(id, {}) if reactions.get(id) is Dictionary else {}
		var en_cours := bool(vu.get("enCours", false))
		for c: Array in CRIS_JOUEUR:
			var ici := en_cours and str(vu.get("cri", "")) == str(c[0])
			var b := Button.new()
			b.name = "FmCriJoueur_%d_%s" % [n, str(c[0])]
			b.flat = true
			b.tooltip_text = str(c[1])
			b.focus_mode = Control.FOCUS_ALL
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.custom_minimum_size = Vector2(px(40), px(40))
			var rond := _rond(str(c[2]), c[3], 38, ici, false, true)
			rond.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			b.add_child(rond)
			var id_j := id
			var id_c := str(c[0])
			b.pressed.connect(func(): crier_joueur(id_j, id_c))
			ligne.add_child(b)
		ligne.add_child(_reaction(vu))

## Réaction au dernier cri, découverte après coup : ▲ bien pris (vert), ▼ mal pris (rouge), « — » il n'écoute plus ;
## la minute du cri en petit. Rien tant qu'on ne lui a rien dit.
func _reaction(vu: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.custom_minimum_size.x = px(74)
	h.add_theme_constant_override("separation", px(4))
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if vu.is_empty(): return h
	var sens := int(vu.get("sens", 0))
	var couleur: Color = Charte.GAIN if sens > 0 else Charte.PERTE if sens < 0 else PAL.encre3
	var fleche := _texte("▲" if sens > 0 else "▼" if sens < 0 else "—", 20, couleur)
	fleche.name = "FmCriReaction"
	h.add_child(fleche)
	var minute := _texte("%d′" % int(vu.get("minute", 0)), 15, PAL.encre if bool(vu.get("enCours", false)) else PAL.encre3)
	minute.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(minute)
	return h

# ------------------------------------------------------------------ barre du banc, toujours visible

func _barre_b(page: Control) -> void:
	barre_b = PanelContainer.new()
	barre_b.name = "FmBancBarre"
	var st: StyleBoxFlat = between.liserer(between._case(Charte.PANNEAU, Charte.RAYON_PANNEAU))
	st.content_margin_left = px(22)
	st.content_margin_right = px(22)
	st.content_margin_top = px(4)
	st.content_margin_bottom = px(4)
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
		var en_cours := str(actif.get("id", "")) == id
		var b := _bouton_rond("FmCri_" + id, str(def[0]), def[1], str(def[2]), en_cours, dispo, func(): crier(id),
			("→ %d′" % int(actif.get("jusqua", 0))) if en_cours else "", float(o.get("usure", 0.0)))
		b.tooltip_text = str(o.get("label", def[2]))
		h.add_child(b)
	var ouvert := is_instance_valid(_menu)
	# Rond « À un joueur » : allumé et enfoncé (fond éclairé, liseré or) tant que sa liste est ouverte.
	var joueur := _bouton_rond("FmBancJoueur", "people", Charte.OR if ouvert else Charte.IVOIRE_2, "À un joueur", ouvert, true, ouvrir_joueurs, "", -1.0)
	if ouvert:
		for etat: String in ["normal", "hover", "pressed", "hover_pressed"]:
			var st := StyleBoxFlat.new()
			st.bg_color = Charte.PANNEAU_3
			st.border_color = Charte.OR
			st.set_border_width_all(maxi(2, px(2)))
			st.set_corner_radius_all(Charte.RAYON_PETIT)
			joueur.add_theme_stylebox_override(etat, st)
	joueur.set_meta("ouvert", ouvert)
	h.add_child(joueur)
	var sep := ColorRect.new()
	sep.color = Charte.FILET
	sep.custom_minimum_size = Vector2(px(2), px(52))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sep)
	var titre_aj := _texte("AJUSTEMENTS", 22, Charte.IVOIRE, true)
	titre_aj.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(titre_aj)
	for aj: Array in AJUSTEMENTS:
		var b := _bouton_rond("FmAjust_" + str(aj[0]), str(aj[2]), FAMILLES[str(aj[5])], str(aj[7]), ajustement_actif(aj), true, func(): basculer(aj), "", -1.0)
		b.tooltip_text = str(aj[1]) + "\n" + "\n".join((aj[6] as Array).map(func(e: Array): return ("▲ " if int(e[1]) > 0 else "▼ ") + str(e[0])))
		h.add_child(b)
	# Permuter les ailes : au prochain arrêt de jeu (« ⧗ » tant qu'il attend), allumé une fois les ailiers échangés.
	var ailes := _ailes()
	var attente := bool(ailes.get("attente", false))
	var permutees := bool(ailes.get("permutees", false))
	var b_ailes := _bouton_rond("FmAjust_ailes", "ailes", Charte.MORAL, "Ailes ⧗" if attente else "Ailes", permutees and not attente, true, permuter_ailes, "", -1.0, attente)
	b_ailes.tooltip_text = "Permuter les ailes"
	h.add_child(b_ailes)

## Rond + mot dessous ; allumé : aplat de couleur. `marque` (minute de fin) et usure du cri en petit à droite.
func _bouton_rond(nom: String, icone: String, couleur: Color, mot: String, allume: bool, actif: bool, action: Callable, marque: String, usure: float, attente: bool = false) -> Button:
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
	b.custom_minimum_size = Vector2(px(92), px(66))
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
	var rond := _rond(icone, couleur if actif else Charte.IVOIRE_3, 40, allume, attente)
	haut.add_child(rond)
	if usure >= 0.0 and not allume: haut.add_child(_usure_vertical(usure))
	var l := _texte(marque if not marque.is_empty() else mot, 16, (couleur if allume or attente else Charte.IVOIRE) if actif else Charte.IVOIRE_3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return b

## Usure d'un cri d'équipe en trois points (plein : intact ; à moitié ; vide : ils n'écoutent plus).
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
