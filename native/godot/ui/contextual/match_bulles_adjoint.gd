extends Node
## Conseils de Gabi en bulles dans sa carte (idée FM27 n° 35, choix de Léo du 23/11/2026) et phrase de jeu en aplat
## coloré, sur l'écran 2D du direct (match_between.gd).
## - Bulles DANS la carte de l'adjoint (jamais sur le terrain), sous sa phrase. Un clic sur la bulle = conseil accepté,
##   aucun bouton Confirmer ; ✕ l'écarte. Accepté, il attend le PROCHAIN ARRÊT DE JEU (file du moteur,
##   native/engine/match-arrets.cjs, auteur 'adjoint') : la bulle passe en attente (⧗) jusqu'à l'arrêt, ✕ la retire.
## - Sources (moteur seulement, rien d'inventé) : avis du staff (`live.pilotage.staff.propositions`, commande
##   `appliquer_staff {axes}`), plan de jeu (`live.pilotage.planAvis`, commande `file_arret`), changement
##   (`live.pilotage.conseilChangement`, commande `file_arret`). Sans avis de l'adjoint : AUCUNE bulle.
## - Incertitude : la justesse des conseils dépend de la compétence de l'adjoint (moteur) ; aucune bulle ne chiffre
##   l'effet d'un changement.
## - Sans file du prochain arrêt (ancien direct) : rien ici, la carte garde son bouton d'origine.
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")
const MenuJoueur = preload("res://ui/contextual/match_menu_joueur.gd")

const NOM := "MatchBullesAdjoint"
const BOITE := "MatchBetweenAdviceBubbles"
const MAX_BULLES := 2
const JAUNE_CARTON := Color("f0cf45")

var between: Control
var _boite: VBoxContainer
var _cle := ""
var _cle_phrase := ""
var _minute_vue := -1

static func poser(hote: Control) -> Node:
	var a := new()
	a.name = NOM
	a.between = hote
	hote.add_child(a)
	return a

func px(v: float) -> int: return between.px(v)

func _pilotage() -> Dictionary:
	var p: Variant = _live().get("pilotage")
	return p if p is Dictionary else {}

func _live() -> Dictionary:
	var d: Variant = between.get("_dernier")
	return d[1] if d is Array and (d as Array).size() > 1 and d[1] is Dictionary else {}

func _direct() -> Dictionary:
	var d: Variant = between.get("_dernier")
	return d[2] if d is Array and (d as Array).size() > 2 and d[2] is Dictionary else {}

func _minute() -> int: return int(_live().get("minute", 0))

## La file du prochain arrêt de jeu existe pour ce match (carrière Monde, pilotage actif).
func actif() -> bool: return not MenuJoueur.arrets(_live()).is_empty()

func _file() -> Array:
	var f: Variant = MenuJoueur.arrets(_live()).get("file")
	return (f as Array).filter(func(e: Variant) -> bool: return e is Dictionary) if f is Array else []

## Conseils écartés d'un clic sur ✕ (pour ce match ; vidés quand la minute repart en arrière).
func _ecartes() -> Dictionary:
	if not between.has_meta("bulles_ecartees"): between.set_meta("bulles_ecartees", {})
	return between.get_meta("bulles_ecartees")

# ------------------------------------------------------------------ les conseils

## Bulles à montrer : [{cle, sorte: "attente"|"consigne"|"plan"|"changement", …}] ; [] sans avis de l'adjoint.
func bulles() -> Array:
	if not actif() or bool(_live().get("finished", false)): return []
	var r: Array = []
	var file := _file()
	# Conseils déjà acceptés : en attente du prochain arrêt de jeu.
	for e: Dictionary in file:
		if str(e.get("auteur", "")) == "adjoint": r.append({"cle": "attente:" + str(e.get("cle", "")), "sorte": "attente", "fileCle": str(e.get("cle", "")), "texte": str(e.get("texte", "")), "type": str(e.get("type", ""))})
	var en_file := func(cle: String) -> bool: return file.any(func(e: Dictionary) -> bool: return str(e.get("cle", "")) == cle)
	var p := _pilotage()
	# Changement conseillé (le plus urgent).
	var ch: Variant = p.get("conseilChangement")
	if ch is Dictionary and not en_file.call("remplacement:%d" % int(ch.get("slot", -1))) and not file.any(func(e: Dictionary) -> bool: return str(e.get("inId", "")) == str(ch.get("inId", ""))):
		var sortant := _joueur(str(ch.get("outId", "")))
		var entrant := _joueur(str(ch.get("inId", "")))
		if not sortant.is_empty() and not entrant.is_empty():
			r.append({"cle": "changement:%s:%s" % [str(ch.outId), str(ch.inId)], "sorte": "changement", "slot": int(ch.get("slot", 0)), "out": sortant, "in": entrant, "raison": str(ch.get("texte", ""))})
	# Consignes du staff, une bulle par raison (deux consignes d'un même constat vont ensemble).
	var staff: Variant = p.get("staff")
	var props: Array = staff.get("propositions", []) if staff is Dictionary and staff.get("propositions") is Array else []
	var groupes := {}
	var ordre: Array = []
	for x: Variant in props:
		if not x is Dictionary or en_file.call("consigne:" + str(x.get("axe", ""))): continue
		var raison := str(x.get("raison", ""))
		if not groupes.has(raison):
			groupes[raison] = []
			ordre.append(raison)
		groupes[raison].append(x)
	for raison: String in ordre:
		var lignes: Array = groupes[raison]
		r.append({"cle": "consigne:%d:%s" % [int(staff.get("minute", -1)), ",".join(lignes.map(func(x: Dictionary) -> String: return "%s=%s" % [x.axe, x.valeur]))], "sorte": "consigne",
			"axes": lignes.map(func(x: Dictionary) -> String: return str(x.axe)), "lignes": lignes, "raison": raison})
	# Plan de jeu (attaque, défense) : une bulle.
	var plan: Variant = p.get("planAvis")
	if plan is Array and not (plan as Array).is_empty():
		var lignes_p: Array = (plan as Array).filter(func(x: Variant) -> bool: return x is Dictionary and not en_file.call("consigne:" + str(x.get("axe", ""))))
		if not lignes_p.is_empty():
			r.append({"cle": "plan:" + ",".join(lignes_p.map(func(x: Dictionary) -> String: return "%s=%s" % [x.axe, x.valeur])), "sorte": "plan", "lignes": lignes_p,
				"raison": "\n".join(lignes_p.map(func(x: Dictionary) -> String: return str(x.get("raison", ""))))})
	r = r.filter(func(b: Dictionary) -> bool: return not _ecartes().has(str(b.cle)))
	return r.slice(0, MAX_BULLES)

func _joueur(id: String) -> Dictionary:
	var live := _live()
	for j: Variant in (live.get("lineup", []) if live.get("lineup") is Array else []) + (live.get("reserves", []) if live.get("reserves") is Array else []):
		if j is Dictionary and str(j.get("id", "")) == id: return j
	return {}

# ------------------------------------------------------------------ actions (un clic, aucun Confirmer)

func accepter(b: Dictionary) -> void:
	var app: Object = between._app()
	if app == null: return
	match str(b.sorte):
		"consigne": app._command("appliquer_staff", {"axes": b.axes})
		"plan":
			for x: Dictionary in b.lignes: app._command("file_arret", {"action": "ajouter", "change": {"type": "consigne", "axe": str(x.axe), "valeur": str(x.valeur)}, "auteur": "adjoint"})
		"changement": app._command("file_arret", {"action": "ajouter", "change": {"type": "remplacement", "slot": int(b.slot), "inId": str(b["in"].get("id", ""))}, "auteur": "adjoint"})
	rafraichir(true)

func ecarter(b: Dictionary) -> void:
	if str(b.sorte) == "attente":
		var app: Object = between._app()
		if app != null: app._command("file_arret", {"action": "retirer", "cle": str(b.fileCle)})
	else: _ecartes()[str(b.cle)] = true
	rafraichir(true)

# ------------------------------------------------------------------ rafraîchissement

func rafraichir(force: bool = false) -> void:
	var m := _minute()
	if m < _minute_vue: _ecartes().clear()
	_minute_vue = m
	appliquer_phrase()
	var bs := bulles()
	var cle := JSON.stringify([bs, between.get_viewport_rect().size])
	if cle == _cle and is_instance_valid(_boite) and not force: return
	_cle = cle
	_dessiner(bs)

## Appelé après la reconstruction de la carte de Gabi (match_between._remplir_adjoint, qui la vide).
func apres_adjoint() -> void:
	_cle = ""
	rafraichir(true)

# ------------------------------------------------------------------ dessin

func _texte(t: String, taille: float, couleur: Color, titre: bool = false) -> Label:
	var l: Label = between._texte(t, taille, couleur, false, titre)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _puce(t: String, couleur: Color, plein: bool, taille: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Charte.style_pilule(couleur if plein else Color(couleur, 0.16), Color.TRANSPARENT, px(10), px(2)))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(_texte(t, taille, Charte.ENCRE if plein else couleur))
	return p

func _icone(id: String, couleur: Color, cote: float) -> TextureRect:
	var t := C.icon(id, 25, couleur)
	t.custom_minimum_size = Vector2(px(cote), px(cote))
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Maillot numéroté (sortant rouge, entrant vert, vrai numéro de feuille) + nom court + énergie.
func _maillot(j: Dictionary, numero: int, couleur: Color, taille: float) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", px(6))
	var rond := PanelContainer.new()
	rond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rond.add_theme_stylebox_override("panel", Charte.style_pilule(couleur, Color.TRANSPARENT, px(7), px(1)))
	rond.custom_minimum_size = Vector2(px(taille * 1.7), 0)
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

func _croix(nom: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = nom
	b.text = "✕"
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", between.fpx(20))
	for k in ["font_color", "font_focus_color"]: b.add_theme_color_override(k, Charte.IVOIRE_2)
	b.add_theme_color_override("font_hover_color", Charte.PERTE)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(action)
	return b

## Fond de bulle : coin haut gauche droit (la bulle « sort » de Gabi), liseré coloré à gauche, plus clair au survol.
func _habiller(b: Button, liseré: Color, attente: bool) -> void:
	for etat: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		var st := StyleBoxFlat.new()
		var survol := etat in ["hover", "pressed", "hover_pressed"] and not attente
		st.bg_color = Color("2c3637") if survol else (Charte.PANNEAU_2 if attente else Charte.PANNEAU_3)
		st.set_corner_radius_all(Charte.RAYON_CARTE)
		st.corner_radius_top_left = 0
		st.anti_aliasing = true
		st.border_color = liseré
		st.border_width_left = px(6)
		if etat == "focus":
			st.bg_color = Color(0, 0, 0, 0)
			st.border_color = Charte.OR
			st.set_border_width_all(2)
		b.add_theme_stylebox_override(etat, st)

const SORTES := {
	"consigne": ["Consigne", "tactic"],
	"plan": ["Plan de jeu", "tactic"],
	"changement": ["Changement", "renew"],
	"attente": ["Prochain arrêt de jeu", "hourglass"]}

func _couleur(sorte: String) -> Color:
	return {"consigne": Charte.INTENSIF, "plan": Charte.ATTRIBUT_55, "changement": Charte.MORAL, "attente": JAUNE_CARTON}.get(sorte, Charte.IVOIRE_2)

func _dessiner(bs: Array) -> void:
	var adjoint: Variant = between.get("adjoint")
	if is_instance_valid(_boite):
		if _boite.get_parent() != null: _boite.get_parent().remove_child(_boite)
		_boite.queue_free()
	_boite = null
	if bs.is_empty() or not adjoint is Control or not is_instance_valid(adjoint): return
	_boite = VBoxContainer.new()
	_boite.name = BOITE
	_boite.add_theme_constant_override("separation", px(8))
	(adjoint as Control).add_child(_boite)
	# Juste sous la parole de Gabi (avant ses actions).
	(adjoint as Control).move_child(_boite, mini(1, (adjoint as Control).get_child_count() - 1))
	var i := 0
	for b: Dictionary in bs:
		i += 1
		_boite.add_child(_bulle(b, i))
	# Avec des bulles, la parole de Gabi tient sur deux lignes (le reste en infobulle) : la carte reste basse.
	for l: Node in (adjoint as Control).find_children("*", "Label", true, false):
		var e := l as Label
		if e.max_lines_visible > 2 and not _boite.is_ancestor_of(e):
			e.max_lines_visible = 2
			e.custom_minimum_size.y = between.hauteur_lignes(e, 2)

func _bulle(b: Dictionary, i: int) -> Button:
	var sorte := str(b.sorte)
	var attente := sorte == "attente"
	var couleur := _couleur(sorte)
	var bouton := Button.new()
	bouton.name = "MatchBetweenAdviceBubble_%d" % i
	bouton.set_meta("sorte", sorte)
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_ARROW if attente else Control.CURSOR_POINTING_HAND
	bouton.tooltip_text = str(b.get("raison", ""))
	_habiller(bouton, couleur, attente)
	var conseil := b
	if not attente: bouton.pressed.connect(func(): accepter(conseil))
	var marge := MarginContainer.new()
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(k, px({"margin_left": 18, "margin_right": 4, "margin_top": 6, "margin_bottom": 6}[k]))
	bouton.add_child(marge)
	# Une seule rangée : l'icône de la sorte (couleur du liseré), le conseil, ✕ (la sorte et la raison en infobulle).
	var rangee := HBoxContainer.new()
	rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rangee.add_theme_constant_override("separation", px(10))
	marge.add_child(rangee)
	var icone := _icone(SORTES[sorte][1], couleur, 26)
	icone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rangee.add_child(icone)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", px(4))
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(col)
	rangee.add_child(_croix("MatchBetweenAdviceBubbleClose_%d" % i, func(): ecarter(conseil)))
	var raison := str(b.get("raison", ""))
	bouton.tooltip_text = str(SORTES[sorte][0]) + ("\n" + raison if not raison.is_empty() else "")
	match sorte:
		"attente":
			var l := _texte(str(b.texte), 18, Charte.IVOIRE)
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.custom_minimum_size.x = px(120)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bouton.tooltip_text = str(SORTES.attente[0]) + "\n" + str(b.texte)
			col.add_child(l)
		"changement":
			var h := HFlowContainer.new()
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_theme_constant_override("h_separation", px(8))
			h.add_theme_constant_override("v_separation", px(4))
			col.add_child(h)
			var live := _live()
			h.add_child(_maillot(b.out, MenuJoueur.numero_feuille(live, str(b.out.get("id", "")), int(b.slot) + 1), Charte.PERTE, 17))
			h.add_child(_texte("→", 17, Charte.IVOIRE_2))
			h.add_child(_maillot(b["in"], MenuJoueur.numero_feuille(live, str(b["in"].get("id", "")), 16), Charte.GAIN, 17))
		_:
			for x: Dictionary in b.lignes:
				var h := HFlowContainer.new()
				h.mouse_filter = Control.MOUSE_FILTER_IGNORE
				h.add_theme_constant_override("h_separation", px(8))
				h.add_theme_constant_override("v_separation", px(4))
				col.add_child(h)
				h.add_child(_texte(str(x.get("label", "")), 18, Charte.IVOIRE, true))
				if not str(x.get("actuelLabel", "")).is_empty():
					h.add_child(_puce(str(x.actuelLabel), Charte.IVOIRE_2, false, 15))
					h.add_child(_texte("→", 16, Charte.IVOIRE_2))
				h.add_child(_puce(str(x.get("valeurLabel", "")), Charte.GAIN, true, 15))
	# Le bouton prend la hauteur de son contenu (le contenu est posé par ancres, pas par conteneur).
	marge.minimum_size_changed.connect(func(): if is_instance_valid(bouton): bouton.custom_minimum_size.y = marge.get_combined_minimum_size().y)
	bouton.custom_minimum_size.y = marge.get_combined_minimum_size().y
	return bouton

# ------------------------------------------------------------------ phrase de jeu en aplat coloré

## Dernier fait marquant (essai, but, carton) : [sorte, texte, minute] ; [] sans fait.
func _dernier_fait() -> Array:
	var reperes: Array = _direct().get("reperes", []) if _direct().get("reperes") is Array else []
	if reperes.is_empty() or not reperes[-1] is Dictionary: return []
	var r: Dictionary = reperes[-1]
	var kind := str(r.get("kind", r.get("type", "")))
	var nom := str(r.get("nom", ""))
	var minute := int(r.get("minute", 0))
	if kind == "card":
		var rouge := bool(r.get("rouge", false))
		return ["rouge" if rouge else "jaune", ("Carton %s pour %s" % ["rouge" if rouge else "jaune", nom]) if not nom.is_empty() else "", minute]
	if kind == "try": return ["essai", ("Essai de %s" % nom) if not nom.is_empty() else "", minute]
	return ["but", ("%s passe les poteaux" % nom) if not nom.is_empty() else "", minute]

func appliquer_phrase() -> void:
	var cadre: Variant = between.get("phrase_fm")
	var etat: Variant = between.get("etat")
	if not cadre is PanelContainer or not is_instance_valid(cadre) or not etat is Label: return
	var fait := _dernier_fait()
	# Le fait marquant des 3 dernières minutes prend la phrase de jeu ; plus ancien, la phrase reste celle du jeu.
	var recent := not fait.is_empty() and _minute() - int(fait[2]) <= 3 and not str(fait[1]).is_empty()
	# Texte imposé par la régie (plan 3D, liaison) : il reste tel quel.
	if not str(between.get("etat_force")).is_empty(): recent = false
	# Carton : seulement tant qu'il est l'arrêt en cours (jusqu'à la reprise du jeu, jamais pendant un autre arrêt).
	if recent and str(fait[0]) in ["jaune", "rouge"] and between.has_method("carton_en_cours") and not between.carton_en_cours(): recent = false
	if recent: (etat as Label).text = str(fait[1])
	var sorte := str(fait[0]) if recent else ""
	var cle := JSON.stringify([sorte, (etat as Label).text])
	if cle == _cle_phrase: return
	_cle_phrase = cle
	var panneau := cadre as PanelContainer
	if not panneau.has_meta("style_origine"): panneau.set_meta("style_origine", panneau.get_theme_stylebox("panel"))
	var st := (panneau.get_meta("style_origine") as StyleBoxFlat).duplicate() as StyleBoxFlat
	(etat as Label).remove_theme_color_override("font_color")
	var ligne := (etat as Label).get_parent()
	var ancienne := ligne.get_node_or_null("MatchBetweenPlayLineTag")
	if ancienne != null:
		ligne.remove_child(ancienne)
		ancienne.queue_free()
	var trait_v: Variant = between.get("phrase_trait_fm")
	if sorte.is_empty():
		panneau.add_theme_stylebox_override("panel", st)
		return
	var couleur: Color = {"essai": Charte.GAIN, "but": Charte.MORAL, "jaune": JAUNE_CARTON, "rouge": Charte.PERTE}[sorte]
	st.bg_color = couleur
	panneau.add_theme_stylebox_override("panel", st)
	(etat as Label).add_theme_color_override("font_color", Charte.ENCRE)
	if trait_v is ColorRect: (trait_v as ColorRect).color = Color(Charte.ENCRE, 0.6)
	var pastille := PanelContainer.new()
	pastille.name = "MatchBetweenPlayLineTag"
	pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pastille.add_theme_stylebox_override("panel", Charte.style_pilule(Charte.ENCRE, Color.TRANSPARENT, px(14), px(4)))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", px(8))
	pastille.add_child(h)
	if sorte in ["jaune", "rouge"]:
		var carte := ColorRect.new()
		carte.color = couleur
		carte.custom_minimum_size = Vector2(px(16), px(22))
		carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(carte)
	else: h.add_child(_icone({"essai": "ball", "but": "target"}[sorte], couleur, 24))
	h.add_child(_texte({"essai": "ESSAI", "but": "AU BUT", "jaune": "CARTON JAUNE", "rouge": "CARTON ROUGE"}[sorte], 18, couleur, true))
	ligne.add_child(pastille)
	ligne.move_child(pastille, (etat as Label).get_index())
