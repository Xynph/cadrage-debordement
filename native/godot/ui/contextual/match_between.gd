extends Control
## Écran intermédiaire du direct en temps forts (CD_MATCH_TEMPS_FORTS=1).
## Il n'affiche que la projection `live.direct` du moteur : zone de jeu et possession
## sur un terrain vu de dessus, fil, chiffres, regard de l'adjoint. Aucun calcul sportif.
## Contenu et hiérarchie seulement : composants et couleurs de l'habillage existant.
const S = preload("res://ui/contextual/skin.gd")

signal niveau_choisi(id: String)
signal reprise_demandee
signal tiroir_demande(titre: String)

var terrain: Terrain
var etat: Label
var niveau: OptionButton
var fil: VBoxContainer
var chiffres: VBoxContainer
var adjoint: VBoxContainer
var adjoint_cadre: Control
var arret: PanelContainer
var arret_titre: Label
var arret_texte: Label
var _niveaux: Array = []
var _cle := ""
var _densite := 0.5
var _arret: Dictionary = {}
var _dernier: Array = []

## Terrain vu de dessus : 100 m de champ de jeu et deux en-buts de 8 m.
class Terrain extends Control:
	const S = preload("res://ui/contextual/skin.gd")
	const EN_BUT := 8.0
	var direct: Dictionary = {}
	var equipes: Array = []
	var couleurs: Array[Color] = [Color("d43e47"), Color("6f9ac9")]
	## Échelle de l'interface (1 en 2560×1440, 0,5 en 1280×720).
	var densite := 0.5

	func px(valeur: float) -> float:
		return valeur * densite

	func champ() -> Rect2:
		var libre := size - Vector2(px(32), px(68))
		var echelle := minf(libre.x / (100.0 + 2.0 * EN_BUT), libre.y / 70.0)
		var taille := Vector2((100.0 + 2.0 * EN_BUT) * echelle, 70.0 * echelle)
		return Rect2((size - taille) * 0.5 + Vector2(0, px(16)), taille)

	func point(x: float, y: float) -> Vector2:
		var c := champ()
		var echelle := c.size.y / 70.0
		return c.position + Vector2((EN_BUT + clampf(x, -EN_BUT, 100.0 + EN_BUT)) * echelle, clampf(y, 0.0, 70.0) * echelle)

	func _draw() -> void:
		var c := champ()
		if c.size.x <= 40.0 or c.size.y <= 30.0: return
		var echelle := c.size.y / 70.0
		var police := get_theme_default_font()
		var ligne := Color(S.MUTED, 0.75)
		draw_rect(c, Color("283e2d"))
		for cote in 2:
			var en_but := Rect2(point(-EN_BUT if cote == 0 else 100.0, 0), Vector2(EN_BUT * echelle, c.size.y))
			draw_rect(en_but, Color(couleurs[cote], 0.42))
			var nom := S.G.club_abbr(equipes[cote]) if equipes.size() > cote and equipes[cote] is Dictionary else ""
			if not nom.is_empty():
				var centre := en_but.get_center()
				draw_set_transform(centre, -PI / 2.0 if cote == 0 else PI / 2.0)
				draw_string(police, Vector2(-c.size.y * 0.5, px(10)), nom, HORIZONTAL_ALIGNMENT_CENTER, c.size.y, roundi(px(28)), S.TEXT)
				draw_set_transform(Vector2.ZERO, 0.0)
		# Zone de jeu : la bande de dix mètres où se trouve le ballon.
		var zone: Dictionary = direct.get("zone", {})
		var x := clampf(float(zone.get("x", 50.0)), 0.0, 100.0)
		var debut := clampf(floorf(x / 10.0) * 10.0, 0.0, 90.0)
		draw_rect(Rect2(point(debut, 0), Vector2(10.0 * echelle, c.size.y)), Color(S.GOLD, 0.20))
		draw_rect(Rect2(point(debut, 0), Vector2(10.0 * echelle, c.size.y)), Color(S.GOLD, 0.85), false, maxf(2.0, px(4)))
		for metre in [0.0, 22.0, 50.0, 78.0, 100.0]:
			draw_line(point(metre, 0), point(metre, 70), ligne, 2.0 if metre in [0.0, 50.0, 100.0] else 1.5)
		for metre in [5.0, 40.0, 60.0, 95.0]:
			draw_dashed_line(point(metre, 0), point(metre, 70), Color(ligne, 0.5), 1.0, 6.0)
		for largeur in [5.0, 15.0, 55.0, 65.0]:
			draw_dashed_line(point(0, largeur), point(100, largeur), Color(ligne, 0.35), 1.0, 6.0)
		draw_rect(c, ligne, false, 2.0)
		for repere in [[22.0, "22"], [50.0, "50"], [78.0, "22"]]:
			draw_string(police, point(repere[0], 0) + Vector2(-px(40), -px(10)), repere[1], HORIZONTAL_ALIGNMENT_CENTER, px(80), roundi(px(24)), S.MUTED)
		# Les trois dernières actions, de la plus ancienne à la plus récente.
		var traces: Array = direct.get("traces", [])
		for index in traces.size():
			var trace: Dictionary = traces[index]
			var depuis: Dictionary = trace.get("depuis", {})
			var vers: Dictionary = trace.get("vers", {})
			var a := point(float(depuis.get("x", x)), float(depuis.get("y", 35.0)))
			var b := point(float(vers.get("x", x)), float(vers.get("y", 35.0)))
			if a.distance_to(b) < 3.0: continue
			var force := 0.35 + 0.3 * float(index + 1) / float(traces.size())
			draw_line(a, b, Color(S.TEXT, force), maxf(2.0, px(4)), true)
			var sens := (b - a).normalized()
			draw_colored_polygon(PackedVector2Array([b, b - sens * px(18) + sens.orthogonal() * px(9), b - sens * px(18) - sens.orthogonal() * px(9)]), Color(S.TEXT, force))
		# Essais, pénalités et cartons déjà joués.
		for repere: Dictionary in direct.get("reperes", []):
			var equipe := int(repere.get("equipe", 0))
			var kind := str(repere.get("kind", ""))
			var ou := point(clampf(float(repere.get("x", 50.0)), -3.0, 103.0) if kind != "try" else (103.0 if equipe == 0 else -3.0), float(repere.get("y", 35.0)))
			var teinte := couleurs[clampi(equipe, 0, 1)]
			if kind == "card":
				teinte = Color("d43e47") if repere.get("rouge", false) else S.GOLD
				draw_rect(Rect2(ou - Vector2(px(8), px(12)), Vector2(px(16), px(24))), teinte)
			else:
				draw_circle(ou, px(16), teinte)
				draw_arc(ou, px(16), 0.0, TAU, 20, S.TEXT, maxf(1.5, px(3)), true)
				draw_string(police, ou + Vector2(-px(16), px(8)), "E" if kind == "try" else "P", HORIZONTAL_ALIGNMENT_CENTER, px(32), roundi(px(22)), S.TEXT)
			draw_string(police, ou + Vector2(-px(40), px(44)), str(repere.get("horloge", "")), HORIZONTAL_ALIGNMENT_CENTER, px(80), roundi(px(22)), S.MUTED)
		# Ballon et sens du jeu de l'équipe en possession.
		var dernier: Dictionary = traces[-1].get("vers", {}) if not traces.is_empty() else {}
		var ballon := point(x, float(dernier.get("y", 35.0)))
		var possession: Variant = direct.get("possession")
		if possession is float or possession is int:
			var cote := clampi(int(possession), 0, 1)
			var sens := Vector2(1 if cote == 0 else -1, 0)
			var pointe := ballon + sens * px(68)
			draw_line(ballon + sens * px(24), pointe, couleurs[cote], maxf(4.0, px(10)), true)
			draw_colored_polygon(PackedVector2Array([pointe + sens * px(20), pointe + sens.orthogonal() * px(16), pointe - sens.orthogonal() * px(16)]), couleurs[cote])
		draw_circle(ballon, px(14), S.TEXT)
		draw_arc(ballon, px(22), 0.0, TAU, 24, S.GOLD, maxf(2.0, px(4)), true)

## Échelle de l'interface, comme les autres écrans du jeu (immersive08/components.gd) :
## les tailles sont écrites pour 2560×1440 et réduites jusqu'à la moitié en 1280×720.
static func densite_pour(taille: Vector2) -> float:
	return clampf(minf(taille.y / 1440.0, taille.x / 2560.0), 0.5, 1.0)

func px(valeur: float) -> int:
	return roundi(valeur * _densite)

func _texte(texte: String, taille: float, couleur: Color, retour: bool = false) -> Label:
	var etiquette := S.wrap(texte, px(taille), couleur) if retour else S.label(texte, px(taille), couleur)
	etiquette.add_theme_font_size_override("font_size", px(taille))
	return etiquette

func _bouton(texte: String, action: Callable, actif: bool = true, principal: bool = false) -> Button:
	var bouton := S.button(texte, action, actif, principal)
	bouton.custom_minimum_size.y = px(76)
	bouton.add_theme_font_size_override("font_size", px(26))
	return bouton

func _ready() -> void:
	name = "MatchBetween"
	mouse_filter = Control.MOUSE_FILTER_PASS
	S.full(self)
	_densite = densite_pour(get_viewport_rect().size)
	_construire()
	resized.connect(_a_l_echelle)

## La fenêtre a changé de taille : tout l'écran est reconstruit à la nouvelle échelle.
func _a_l_echelle() -> void:
	var densite := densite_pour(get_viewport_rect().size)
	if is_equal_approx(densite, _densite): return
	_densite = densite
	_construire()
	if not _dernier.is_empty(): update_frame.callv(_dernier)

func _construire() -> void:
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	_cle = ""
	var page := S.G.v(px(16))
	S.full(page)
	add_child(page)
	var entete := S.G.h(px(20))
	page.add_child(entete)
	etat = _texte("", 34, S.GOLD)
	etat.name = "MatchBetweenState"
	etat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etat.clip_text = true
	S.G.fill(etat)
	entete.add_child(etat)
	entete.add_child(_texte("Temps forts", 26, S.MUTED))
	niveau = OptionButton.new()
	niveau.name = "MatchHighlightLevel"
	niveau.custom_minimum_size = Vector2(px(400), px(68))
	niveau.add_theme_font_size_override("font_size", px(26))
	niveau.get_popup().add_theme_font_size_override("font_size", px(26))
	niveau.set_meta("contextual_enabled", true)
	niveau.item_selected.connect(func(index: int): if index >= 0 and index < _niveaux.size(): niveau_choisi.emit(str(_niveaux[index].get("id", ""))))
	entete.add_child(niveau)
	var corps := S.G.h(px(20))
	S.G.fill(corps, true)
	page.add_child(corps)
	var gauche := S.panel(corps, px(16))
	S.G.fill(gauche.get_parent().get_parent(), false, 1.6)
	terrain = Terrain.new()
	terrain.name = "MatchBetweenPitch"
	terrain.densite = _densite
	terrain.custom_minimum_size = Vector2(320, 180)
	S.G.fill(terrain, true)
	gauche.add_child(terrain)
	var droite := S.G.v(px(16))
	droite.custom_minimum_size.x = px(660)
	S.G.fill(droite)
	corps.add_child(droite)
	# Le fil prend la hauteur disponible : plus l'écran est grand, plus il remonte loin.
	var journal := S.panel(droite, px(20))
	S.G.fill(journal.get_parent().get_parent(), true, 1.0)
	journal.add_child(_texte("LE FIL", 24, S.GOLD))
	# Défilant : les lignes plus anciennes restent atteignables sans rien pousser hors de l'écran.
	fil = S.G.scroll(journal)
	fil.name = "MatchBetweenFeed"
	fil.add_theme_constant_override("separation", px(8))
	(fil.get_parent() as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	S.G.fill(fil.get_parent(), true)
	var tableau := S.panel(droite, px(20))
	tableau.add_child(_texte("LE MATCH EN CHIFFRES", 24, S.GOLD))
	chiffres = S.G.v(px(4))
	chiffres.name = "MatchBetweenFigures"
	tableau.add_child(chiffres)
	adjoint = S.panel(droite, px(20))
	adjoint.name = "MatchBetweenAdvice"
	adjoint_cadre = adjoint.get_parent().get_parent()
	adjoint_cadre.hide()
	# Arrêt-décision : le match attend le manager.
	arret = PanelContainer.new()
	arret.name = "MatchBetweenStop"
	arret.add_theme_stylebox_override("panel", S.G.T.box(S.PANEL, 5, S.GOLD))
	arret.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	arret.custom_minimum_size = Vector2(px(920), 0)
	arret.grow_horizontal = Control.GROW_DIRECTION_BOTH
	arret.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(arret)
	var marge := S.G.margin(px(32))
	arret.add_child(marge)
	var colonne := S.G.v(px(20))
	marge.add_child(colonne)
	arret_titre = _texte("", 44, S.GOLD)
	colonne.add_child(arret_titre)
	arret_texte = _texte("", 30, S.TEXT, true)
	arret_texte.custom_minimum_size.x = px(840)
	colonne.add_child(arret_texte)
	var choix := S.G.h(px(16))
	colonne.add_child(choix)
	choix.add_child(_bouton("BANC", func(): tiroir_demande.emit("Banc")))
	choix.add_child(_bouton("TACTIQUE", func(): tiroir_demande.emit("Tactique")))
	choix.add_child(S.G.spacer())
	choix.add_child(_bouton("REPRENDRE LE MATCH", func(): reprise_demandee.emit(), true, true))
	arret.hide()
	if not _arret.is_empty(): montrer_arret(_arret)

static func _zone(x: float, possession: int) -> String:
	# Vu de l'équipe en possession : distance jusqu'à la ligne d'essai adverse.
	var reste := 100.0 - x if possession == 0 else x
	if reste <= 22.0: return "dans les 22 mètres adverses"
	if reste <= 50.0: return "dans le camp adverse"
	if reste <= 78.0: return "dans son camp"
	return "dans ses 22 mètres"

func update_frame(model: Dictionary, live: Dictionary, direct: Dictionary, appliquer: Callable) -> void:
	if not is_node_ready(): return
	_dernier = [model, live, direct, appliquer]
	var densite := densite_pour(get_viewport_rect().size)
	if not is_equal_approx(densite, _densite):
		_densite = densite
		_construire()
	var equipes: Array = live.get("teams", [])
	terrain.direct = direct
	terrain.equipes = equipes
	for cote in mini(equipes.size(), 2):
		var club: Dictionary = equipes[cote]
		var teinte := str(club.get("presentation", {}).get("color", club.get("color", "")))
		if not teinte.is_empty(): terrain.couleurs[cote] = Color.from_string(teinte, terrain.couleurs[cote])
	terrain.queue_redraw()
	var possession: Variant = direct.get("possession")
	if live.get("finished", false): etat.text = "MATCH TERMINÉ"
	elif live.get("atBreak", false): etat.text = "MI-TEMPS"
	elif (possession is float or possession is int) and equipes.size() >= 2:
		var cote := clampi(int(possession), 0, 1)
		etat.text = "%s · ballon %s" % [S.G.club_name(equipes[cote]).to_upper(), _zone(float(direct.get("zone", {}).get("x", 50.0)), cote)]
	else: etat.text = "LE MATCH"
	_niveaux = direct.get("niveaux", [])
	if niveau.item_count != _niveaux.size():
		niveau.clear()
		for item: Dictionary in _niveaux: niveau.add_item(str(item.get("label", "")))
	for index in _niveaux.size():
		if _niveaux[index].get("id") == direct.get("niveau") and niveau.selected != index: niveau.select(index)
	var lignes: Array = direct.get("fil", [])
	var cle := JSON.stringify([lignes, direct.get("chiffres", []), model.get("decisions", {}).get("liveAdvice"), live.get("paused", false), live.get("finished", false)])
	if cle == _cle: return
	_cle = cle
	S.clear(fil)
	for index in range(lignes.size() - 1, -1, -1):
		var entree: Dictionary = lignes[index]
		var texte := _texte("%s  %s" % [str(entree.get("horloge", "")), str(entree.get("texte", ""))], 28 if index == lignes.size() - 1 else 26, S.TEXT if index == lignes.size() - 1 else S.MUTED, true)
		texte.max_lines_visible = 2
		texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		fil.add_child(texte)
	S.clear(chiffres)
	for rang: Dictionary in direct.get("chiffres", []):
		var ligne := S.G.h(px(16))
		var titre := _texte(str(rang.get("label", "")), 26, S.MUTED)
		titre.clip_text = true
		S.G.fill(titre)
		ligne.add_child(titre)
		var valeurs := _texte("%s  —  %s" % [str(rang.get("home", "")), str(rang.get("away", ""))], 28, S.TEXT)
		valeurs.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ligne.add_child(valeurs)
		chiffres.add_child(ligne)
	# Le regard de l'adjoint : seulement si le moteur en projette un.
	S.clear(adjoint)
	var conseil: Variant = model.get("decisions", {}).get("liveAdvice")
	adjoint_cadre.visible = conseil is Dictionary and not live.get("finished", false)
	if conseil is Dictionary:
		adjoint.add_child(_texte("LE REGARD DE L’ADJOINT", 24, S.GOLD))
		for raison in [conseil.get("attackReason", ""), conseil.get("defenceReason", "")]:
			if str(raison).is_empty(): continue
			var texte := _texte(str(raison), 26, S.TEXT, true)
			# Petit écran : une ligne par raison, le fil garde la hauteur ; le texte entier reste en infobulle.
			texte.max_lines_visible = 1 if _densite < 0.7 else 2
			texte.tooltip_text = str(raison)
			texte.mouse_filter = Control.MOUSE_FILTER_PASS
			texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			adjoint.add_child(texte)
		# Le bouton n'apparaît que si l'adjoint propose autre chose que les consignes en place.
		var change: bool = conseil.get("attackChanged", false) or conseil.get("defenceChanged", false)
		if change:
			var possible: bool = conseil.get("canAct", false) and conseil.get("defenceAvailable", false)
			var bouton := _bouton("APPLIQUER CES CONSIGNES", func(): appliquer.call(conseil), possible)
			bouton.name = "MatchBetweenApplyAdvice"
			bouton.tooltip_text = "" if possible else "Mettez le match en pause pour modifier vos consignes."
			adjoint.add_child(bouton)

func montrer_arret(valeur: Dictionary) -> void:
	_arret = valeur
	if valeur.is_empty():
		arret.hide()
		return
	var titre := "CARTON ROUGE" if valeur.get("rouge", false) else "CARTON JAUNE"
	arret_titre.text = "%s · %s" % [titre, str(valeur.get("horloge", ""))]
	arret_texte.text = str(valeur.get("texte", "")) + "\nLe match est en pause : réorganisez votre équipe si besoin, puis reprenez."
	arret.show()
