extends Node
## Planche A/B « Conseil de l'adjoint en bulle » (revue FM27, idée 35), sous CD_VARIANTE_VISUELLE=A|B, dans le tableau de
## bord du direct (match_between.gd). Règle de Léo (23/11) : un clic choisit et valide, jamais de bouton Confirmer ;
## un clic sur le conseil l'applique, ✕ l'écarte.
## - Conseils de consigne : avis du staff du moteur (`live.pilotage.staff.propositions`, commande `set_consignes`).
##   Sans avis du staff en attente, la planche en tire un des chiffres du match (provisoire, marqué `provisoire`).
## - Conseil de changement : `live.pilotage.conseilChangement` (sinon le plus entamé du XV et un remplaçant du même poste).
##   Le moteur remplace tout de suite : « en attente jusqu'au prochain arrêt de jeu » n'existe pas (planche seulement :
##   le clic range le changement dans le bandeau, sans commande).
## - Phrase de jeu colorée selon le dernier fait marquant (`direct.reperes` : essai, but, carton).
## A : bulles flottantes de Gabi au-dessus du terrain, bandeau « en attente » en tête du centre, phrase en aplat de couleur.
## B : conseils en lignes dans la carte de Gabi, « en attente » en tête du banc, phrase en ivoire avec pastille colorée.
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

const NOM := "MatchFmAdjoint"
const JAUNE_CARTON := Color("f0cf45")

var between: Control
var variante := ""
var _bulles: VBoxContainer
var _bandeau: PanelContainer
var _cle := ""
var _cle_phrase := ""

static func variante_active() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func poser(hote: Control) -> Node:
	var v := variante_active()
	if v.is_empty(): return null
	var a := new()
	a.name = NOM
	a.between = hote
	a.variante = v
	hote.add_child(a)
	return a

func px(v: float) -> int: return between.px(v)

func _pilotage() -> Dictionary:
	var p: Variant = between.get("_pilotage")
	return p if p is Dictionary else {}

func _live() -> Dictionary:
	var d: Variant = between.get("_dernier")
	return d[1] if d is Array and (d as Array).size() > 1 and d[1] is Dictionary else {}

func _direct() -> Dictionary:
	var d: Variant = between.get("_dernier")
	return d[2] if d is Array and (d as Array).size() > 2 and d[2] is Dictionary else {}

func _ecartes() -> Dictionary:
	if not between.has_meta("fm_ecartes"): between.set_meta("fm_ecartes", {})
	return between.get_meta("fm_ecartes")

func _attente() -> Array:
	if not between.has_meta("fm_attente"): between.set_meta("fm_attente", [])
	return between.get_meta("fm_attente")

func _appliques() -> Dictionary:
	if not between.has_meta("fm_appliques"): between.set_meta("fm_appliques", {})
	return between.get_meta("fm_appliques")

# ------------------------------------------------------------------ les conseils

## Conseils montrés : [{cle, sorte: "consigne"|"changement", ...}], écartés et déjà en place retirés.
func conseils() -> Array:
	var r: Array = []
	var p := _pilotage()
	var consignes: Dictionary = p.get("consignes") if p.get("consignes") is Dictionary else {}
	var staff: Dictionary = p.get("staff") if p.get("staff") is Dictionary else {}
	var props: Array = (staff.get("propositions") if staff.get("propositions") is Array else []).filter(func(x: Variant) -> bool: return x is Dictionary)
	if props.is_empty(): props = _propositions_provisoires(consignes)
	for x: Dictionary in props:
		var cle := "c:%s:%s" % [str(x.get("axe", "")), str(x.get("valeur", ""))]
		if _ecartes().has(cle) or str(consignes.get(str(x.get("axe", "")), "")) == str(x.get("valeur", "")) and not _appliques().has(cle): continue
		r.append({"cle": cle, "sorte": "consigne", "axe": str(x.get("axe", "")), "valeur": str(x.get("valeur", "")), "label": str(x.get("label", "")),
			"valeurLabel": str(x.get("valeurLabel", "")), "actuelLabel": str(x.get("actuelLabel", "")), "provisoire": bool(x.get("provisoire", false)), "fait": _appliques().has(cle)})
	var ch := _changement()
	if not ch.is_empty():
		var cle := "r:%s:%s" % [str(ch.out.get("id", "")), str(ch["in"].get("id", ""))]
		var deja := _attente().any(func(a: Dictionary) -> bool: return str(a.cle) == cle)
		if not _ecartes().has(cle) and not deja: r.append({"cle": cle, "sorte": "changement", "out": ch.out, "in": ch["in"], "slot": int(ch.slot)})
	return r.slice(0, 2)

func _propositions_provisoires(consignes: Dictionary) -> Array:
	var pen := 0
	for ligne: Variant in _direct().get("tableau", []) if _direct().get("tableau") is Array else []:
		if ligne is Dictionary and str(ligne.get("cle", ligne.get("id", ""))) == "penalites":
			var v: Variant = ligne.get("valeurs", ligne.get("values", []))
			if v is Array and v.size() > 0: pen = int(v[0])
	if pen >= 5 and str(consignes.get("discipline", "normale")) != "stricte":
		return [{"axe": "discipline", "valeur": "stricte", "label": "Discipline", "valeurLabel": "Zéro faute", "actuelLabel": "Normale", "provisoire": true}]
	if str(consignes.get("piedJeu", "normal")) != "plus":
		return [{"axe": "piedJeu", "valeur": "plus", "label": "Jeu au pied", "valeurLabel": "Occuper", "actuelLabel": "Équilibré", "provisoire": true}]
	return []

func _changement() -> Dictionary:
	var live := _live()
	if live.get("finished", false): return {}
	var titulaires: Array = (live.get("lineup") if live.get("lineup") is Array else []).filter(func(j: Variant) -> bool: return j is Dictionary)
	var banc: Array = (live.get("reserves") if live.get("reserves") is Array else []).filter(func(j: Variant) -> bool: return j is Dictionary)
	if titulaires.is_empty() or banc.is_empty(): return {}
	var conseil: Variant = _pilotage().get("conseilChangement")
	var sortant: Dictionary = {}
	var entrant: Dictionary = {}
	if conseil is Dictionary:
		for j: Dictionary in titulaires: if str(j.get("id", "")) == str(conseil.get("outId", "")): sortant = j
		for j: Dictionary in banc: if str(j.get("id", "")) == str(conseil.get("inId", "")): entrant = j
	if sortant.is_empty() or entrant.is_empty():
		# Repli de la planche : le plus entamé du XV qui a un remplaçant de la même ligne sur le banc.
		var ordre := titulaires.duplicate()
		ordre.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("condition", 100)) < float(b.get("condition", 100)))
		sortant = {}
		entrant = {}
		for t: Dictionary in ordre:
			for j: Dictionary in banc:
				if entrant.is_empty() and _ligne(str(j.get("pos", ""))) == _ligne(str(t.get("pos", ""))):
					entrant = j
					sortant = t
			if not entrant.is_empty(): break
		if entrant.is_empty(): return {}
	return {"out": sortant, "in": entrant, "slot": titulaires.find(sortant)}

static func _ligne(pos: String) -> String:
	var p := pos.to_lower()
	if p.contains("pilier") or p.contains("talon") or p in ["pg", "pd", "ta"]: return "premiere"
	if p.contains("ligne") or p in ["2l", "3l"]: return "pack"
	if p.contains("demi") or p in ["dm", "do"]: return "demis"
	return "arrieres"

func appliquer(c: Dictionary) -> void:
	if str(c.sorte) == "consigne":
		var app: Object = between._app()
		if app != null: app._command("set_consignes", {"axe": c.axe, "valeur": c.valeur})
		_appliques()[c.cle] = _minute()
	else:
		_attente().append({"cle": c.cle, "out": c.out, "in": c["in"], "slot": c.slot, "minute": _minute()})
	rafraichir(true)

func ecarter(c: Dictionary) -> void:
	_ecartes()[str(c.cle)] = true
	rafraichir(true)

func annuler_attente(cle: String) -> void:
	var a := _attente()
	for i in range(a.size() - 1, -1, -1): if str(a[i].cle) == cle: a.remove_at(i)
	_ecartes()[cle] = true
	rafraichir(true)

func _minute() -> int: return int(_live().get("minute", 0))

# ------------------------------------------------------------------ rafraîchissement

func rafraichir(force: bool = false) -> void:
	var cs := conseils()
	var cle := JSON.stringify([cs, _attente(), variante, between.get_viewport_rect().size])
	_phrase()
	if cle == _cle and not force: return
	_cle = cle
	# Un conseil appliqué reste affiché « ✓ » une minute, puis disparaît.
	for k: Variant in _appliques().keys(): if _minute() - int(_appliques()[k]) >= 1: _ecartes()[k] = true
	if variante == "A": _bulles_a(cs)
	else: _lignes_b(cs)
	_poser_attente()

## Appelé après la reconstruction de la carte de Gabi (match_between._remplir_adjoint).
func apres_adjoint() -> void:
	_cle = ""
	rafraichir(true)

# ------------------------------------------------------------------ dessin

func _texte(t: String, taille: float, couleur: Color, titre: bool = false) -> Label:
	var l: Label = between._texte(t, taille, couleur, false, titre)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _puce(t: String, couleur: Color, plein: bool = false, taille: float = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Charte.style_pilule(couleur if plein else Color(couleur, 0.16), Color.TRANSPARENT, px(12), px(3)))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(_texte(t, taille, Charte.ENCRE if plein else couleur))
	return p

func _icone(id: String, couleur: Color, cote: float) -> TextureRect:
	var t := C.icon(id, 25, couleur)
	t.custom_minimum_size = Vector2(px(cote), px(cote))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t

func _portrait(cote: float) -> TextureRect:
	var portrait := TextureRect.new()
	var image := AtlasTexture.new()
	image.atlas = between.PORTRAIT
	image.region = Rect2(0, 0, 313.5, 313.5)
	image.filter_clip = true
	portrait.texture = image
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(px(cote), px(cote))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var matte := ShaderMaterial.new()
	matte.shader = between.MATTE
	portrait.material = matte
	return portrait

## Maillot numéroté (sortant rouge, entrant vert) : rond coloré + numéro + nom.
func _maillot(j: Dictionary, numero: int, couleur: Color, taille: float) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", px(8))
	var rond := PanelContainer.new()
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = couleur
	st.set_corner_radius_all(Charte.RAYON_PILULE)
	st.content_margin_left = px(8)
	st.content_margin_right = px(8)
	rond.add_theme_stylebox_override("panel", st)
	rond.custom_minimum_size = Vector2(px(taille * 1.7), px(taille * 1.7))
	rond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := _texte(str(numero), taille, Charte.ENCRE, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rond.add_child(n)
	h.add_child(rond)
	h.add_child(_texte(_nom_court(str(j.get("name", ""))), taille, Charte.IVOIRE))
	var cond := float(j.get("condition", -1))
	if cond >= 0: h.add_child(_texte("%d %%" % roundi(cond), taille - 2, Charte.couleur_attribut(cond)))
	return h

static func _nom_court(nom: String) -> String:
	var morceaux := nom.split(" ", false)
	return nom if morceaux.size() < 2 else "%s. %s" % [morceaux[0].left(1), " ".join(morceaux.slice(1))]

func _bouton_croix(nom: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = nom
	b.text = "✕"
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = "Écarter"
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", between.fpx(24))
	for k in ["font_color", "font_focus_color"]: b.add_theme_color_override(k, Charte.IVOIRE_2)
	b.add_theme_color_override("font_hover_color", Charte.PERTE)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	return b

## Fond de bouton (ligne ou bulle) : `fond` au repos, plus clair au survol, liseré coloré à gauche.
func _habiller(b: Button, fond: Color, survol: Color, liseré: Color, rayon: int) -> void:
	for etat: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = survol if etat in ["hover", "pressed", "hover_pressed"] else fond
		st.set_corner_radius_all(rayon)
		st.anti_aliasing = true
		if liseré.a > 0:
			st.border_color = liseré
			st.border_width_left = px(6)
		if etat == "focus":
			st.bg_color = Color(0, 0, 0, 0)
			st.border_color = Charte.OR
			st.set_border_width_all(2)
		b.add_theme_stylebox_override(etat, st)

## Contenu d'un conseil (commun A et B) : consigne « actuel → proposé », ou changement sortant → entrant.
func _corps_conseil(h: HBoxContainer, c: Dictionary, taille: float) -> void:
	if str(c.sorte) == "consigne":
		var fait := bool(c.get("fait", false))
		h.add_child(_icone("check" if fait else "tactic", Charte.GAIN if fait else Charte.INTENSIF, taille * 1.4))
		h.add_child(_texte(str(c.label), taille + 2, Charte.IVOIRE, true))
		if not fait:
			h.add_child(_puce(str(c.actuelLabel), Charte.IVOIRE_2, false, taille - 2))
			h.add_child(_texte("→", taille, Charte.IVOIRE_2))
		h.add_child(_puce(str(c.valeurLabel), Charte.GAIN, true, taille - 2))
	else:
		h.add_child(_icone("renew", Charte.MORAL, taille * 1.4))
		h.add_child(_maillot(c.out, int(c.slot) + 1, Charte.PERTE, taille - 2))
		h.add_child(_texte("→", taille, Charte.IVOIRE_2))
		h.add_child(_maillot(c["in"], int(c.slot) + 1, Charte.GAIN, taille - 2))

# ------------------------------------------------------------------ A : bulles flottantes

func _bulles_a(cs: Array) -> void:
	if not is_instance_valid(_bulles):
		_bulles = VBoxContainer.new()
		_bulles.name = "FmAdjointBulles"
		_bulles.z_index = 40
		_bulles.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bulles.add_theme_constant_override("separation", px(10))
		between.add_child(_bulles)
	for e in _bulles.get_children():
		_bulles.remove_child(e)
		e.queue_free()
	var i := 0
	for c: Dictionary in cs:
		i += 1
		var b := Button.new()
		b.name = "FmConseil_%d" % i
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "Appliquer"
		_habiller(b, Color(Charte.PANNEAU_3, 0.97), Color("2c3637"), Charte.INTENSIF if str(c.sorte) == "consigne" else Charte.MORAL, Charte.RAYON_PANNEAU)
		b.custom_minimum_size = Vector2(px(860), px(96))
		var conseil := c
		b.pressed.connect(func(): appliquer(conseil))
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", px(14))
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = px(22)
		h.offset_right = -px(10)
		b.add_child(h)
		h.add_child(_portrait(64))
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", px(4))
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(col)
		var tete := HBoxContainer.new()
		tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tete.add_theme_constant_override("separation", px(10))
		col.add_child(tete)
		tete.add_child(_texte("GABI", 16, Charte.IVOIRE_2, true))
		tete.add_child(_texte(("AJOUTER CONSIGNE" if str(c.sorte) == "consigne" else "CHANGEMENT") if not bool(c.get("fait", false)) else "APPLIQUÉ", 16,
			Charte.INTENSIF if str(c.sorte) == "consigne" else Charte.MORAL, true))
		var corps := HBoxContainer.new()
		corps.mouse_filter = Control.MOUSE_FILTER_IGNORE
		corps.add_theme_constant_override("separation", px(10))
		col.add_child(corps)
		_corps_conseil(corps, c, 21)
		h.add_child(_bouton_croix("FmConseilEcarter_%d" % i, func(): ecarter(conseil)))
		_bulles.add_child(b)
	_bulles.reset_size()
	var centre := between.find_child("MatchBetweenPitchRow", true, false) as Control
	if centre != null:
		var r := centre.get_global_rect()
		_bulles.position = Vector2(r.position.x + (r.size.x - px(860)) / 2.0, r.position.y + px(70)) - between.get_global_rect().position

# ------------------------------------------------------------------ B : lignes dans la carte de Gabi

func _lignes_b(cs: Array) -> void:
	var carte: Variant = between.get("adjoint_cadre")
	if not carte is Control or not is_instance_valid(carte): return
	var colonne_g := (carte as Control).get_parent()
	var ancien := colonne_g.get_node_or_null("FmAdjointLignes")
	if ancien != null:
		colonne_g.remove_child(ancien)
		ancien.queue_free()
	if cs.is_empty(): return
	var tuile := PanelContainer.new()
	tuile.name = "FmAdjointLignes"
	var st: StyleBoxFlat = between.liserer(between._case(Charte.PANNEAU, Charte.RAYON_PANNEAU))
	st.set_content_margin_all(px(14))
	tuile.add_theme_stylebox_override("panel", st)
	colonne_g.add_child(tuile)
	colonne_g.move_child(tuile, (carte as Control).get_index() + 1)
	var liste := VBoxContainer.new()
	liste.add_theme_constant_override("separation", px(6))
	tuile.add_child(liste)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", px(10))
	liste.add_child(tete)
	tete.add_child(_texte("CONSEILS DE GABI", 20, Charte.IVOIRE, true))
	tete.add_child(_puce("%d" % cs.filter(func(c: Dictionary) -> bool: return not bool(c.get("fait", false))).size(), Charte.INTENSIF, true, 15))
	var i := 0
	for c: Dictionary in cs:
		i += 1
		var b := Button.new()
		b.name = "FmConseil_%d" % i
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "Appliquer"
		_habiller(b, Charte.PANNEAU_2, Charte.PANNEAU_3, Charte.INTENSIF if str(c.sorte) == "consigne" else Charte.MORAL, Charte.RAYON_PETIT)
		b.custom_minimum_size.y = px(64)
		var conseil := c
		b.pressed.connect(func(): appliquer(conseil))
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", px(10))
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = px(16)
		h.offset_right = -px(6)
		b.add_child(h)
		_corps_conseil(h, c, 17)
		var vide := Control.new()
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(vide)
		h.add_child(_bouton_croix("FmConseilEcarter_%d" % i, func(): ecarter(conseil)))
		liste.add_child(b)

# ------------------------------------------------------------------ changements en attente

func _poser_attente() -> void:
	if is_instance_valid(_bandeau):
		_bandeau.get_parent().remove_child(_bandeau)
		_bandeau.queue_free()
	_bandeau = null
	if _attente().is_empty(): return
	_bandeau = PanelContainer.new()
	_bandeau.name = "FmAttente"
	var st: StyleBoxFlat = between.liserer(between._case(Color("2a2a1c") if variante == "A" else Charte.PANNEAU, Charte.RAYON_PANNEAU))
	st.content_margin_left = px(18)
	st.content_margin_right = px(10)
	st.content_margin_top = px(8)
	st.content_margin_bottom = px(8)
	if variante == "A":
		st.border_color = JAUNE_CARTON
		st.border_width_left = px(8)
	_bandeau.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", px(6))
	_bandeau.add_child(col)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", px(10))
	col.add_child(tete)
	tete.add_child(_icone("hourglass", JAUNE_CARTON, 30))
	tete.add_child(_texte("%d CHANGEMENT%s EN ATTENTE" % [_attente().size(), "S" if _attente().size() > 1 else ""], 20, JAUNE_CARTON, true))
	tete.add_child(_puce("prochain arrêt de jeu", Charte.IVOIRE_2, false, 16))
	var i := 0
	for a: Dictionary in _attente():
		i += 1
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", px(10))
		(tete if variante == "A" else col).add_child(ligne)
		ligne.add_child(_maillot(a.out, int(a.slot) + 1, Charte.PERTE, 18))
		ligne.add_child(_texte("→", 18, Charte.IVOIRE_2))
		ligne.add_child(_maillot(a["in"], int(a.slot) + 1, Charte.GAIN, 18))
		var cle := str(a.cle)
		ligne.add_child(_bouton_croix("FmAttenteAnnuler_%d" % i, func(): annuler_attente(cle)))
	if variante == "A":
		var centre := between.find_child("MatchBetweenCentre", true, false) as Control
		if centre != null:
			centre.add_child(_bandeau)
			centre.move_child(_bandeau, 0)
	else:
		var banc := between.find_child("MatchBetweenBenchTile", true, false) as Control
		var colonne := banc.get_parent() if banc != null else null
		if colonne != null:
			colonne.add_child(_bandeau)
			colonne.move_child(_bandeau, banc.get_index())

# ------------------------------------------------------------------ phrase de jeu colorée

## Dernier fait marquant (essai, but, carton) : [sorte, texte] ; [] sans fait.
func _dernier_fait() -> Array:
	var reperes: Array = _direct().get("reperes", []) if _direct().get("reperes") is Array else []
	if reperes.is_empty() or not reperes[-1] is Dictionary: return []
	var r: Dictionary = reperes[-1]
	var kind := str(r.get("kind", r.get("type", "")))
	var nom := str(r.get("nom", ""))
	var minute := int(r.get("minute", 0))
	if kind == "card": return ["rouge" if bool(r.get("rouge", false)) else "jaune", ("Carton %s pour %s" % ["rouge" if bool(r.get("rouge", false)) else "jaune", nom]) if not nom.is_empty() else "", minute]
	if kind == "try": return ["essai", ("Essai de %s" % nom) if not nom.is_empty() else "", minute]
	return ["but", ("%s passe les poteaux" % nom) if not nom.is_empty() else "", minute]

func _phrase() -> void:
	var cadre: Variant = between.get("phrase_fm")
	var etat: Variant = between.get("etat")
	if not cadre is PanelContainer or not is_instance_valid(cadre) or not etat is Label: return
	var fait := _dernier_fait()
	# Le fait marquant des 3 dernières minutes prend la phrase de jeu ; plus ancien, la phrase reste celle du jeu.
	if not fait.is_empty() and _minute() - int(fait[2]) <= 3 and not str(fait[1]).is_empty(): (etat as Label).text = str(fait[1])
	var cle := JSON.stringify([fait, (etat as Label).text, variante])
	if cle == _cle_phrase: return
	_cle_phrase = cle
	var sorte := str(fait[0]) if not fait.is_empty() else ""
	var couleur: Color = {"essai": Charte.GAIN, "but": Charte.MORAL, "jaune": JAUNE_CARTON, "rouge": Charte.PERTE}.get(sorte, Color(0, 0, 0, 0))
	if not (cadre as PanelContainer).has_meta("fm_style"): (cadre as PanelContainer).set_meta("fm_style", (cadre as PanelContainer).get_theme_stylebox("panel"))
	var st := ((cadre as PanelContainer).get_meta("fm_style") as StyleBoxFlat).duplicate() as StyleBoxFlat
	(cadre as PanelContainer).add_theme_stylebox_override("panel", st)
	(etat as Label).remove_theme_color_override("font_color")
	var ligne := (etat as Label).get_parent()
	var ancienne := ligne.get_node_or_null("FmPhrasePastille")
	if ancienne != null:
		ligne.remove_child(ancienne)
		ancienne.queue_free()
	if sorte.is_empty(): return
	var mot: String = {"essai": "ESSAI", "but": "AU BUT", "jaune": "CARTON JAUNE", "rouge": "CARTON ROUGE"}[sorte]
	var icone: String = {"essai": "ball", "but": "target", "jaune": "warning", "rouge": "warning"}[sorte]
	if variante == "A":
		st.bg_color = couleur
		(etat as Label).add_theme_color_override("font_color", Charte.ENCRE)
		var trait_v: Variant = between.get("phrase_trait_fm")
		if trait_v is ColorRect: (trait_v as ColorRect).color = Color(Charte.ENCRE, 0.6)
	else:
		st.border_color = couleur
		st.border_width_left = px(10)
		(etat as Label).remove_theme_color_override("font_color")
	(cadre as PanelContainer).add_theme_stylebox_override("panel", st)
	var pastille := PanelContainer.new()
	pastille.name = "FmPhrasePastille"
	pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pastille.add_theme_stylebox_override("panel", Charte.style_pilule(Charte.ENCRE if variante == "A" else couleur, Color.TRANSPARENT, px(14), px(4)))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", px(8))
	pastille.add_child(h)
	if sorte in ["jaune", "rouge"]:
		var carte := ColorRect.new()
		carte.color = couleur if variante == "A" else Charte.ENCRE
		carte.custom_minimum_size = Vector2(px(16), px(22))
		carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(carte)
	else:
		h.add_child(_icone(icone, couleur if variante == "A" else Charte.ENCRE, 24))
	h.add_child(_texte(mot, 18, couleur if variante == "A" else Charte.ENCRE, true))
	ligne.add_child(pastille)
	ligne.move_child(pastille, (etat as Label).get_index())
