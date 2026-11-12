extends Control
## Écran intermédiaire du match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0).
##
## Entre deux temps forts, le match continue sur un terrain vu de dessus (`match_terrain_2d.gd`) :
## trente pastilles numérotées rejouent les faits du moteur pendant que l'horloge défile. Autour,
## un tableau de bord inspiré des écrans « match overview » des jeux de management de football,
## adapté au rugby : domination minute par minute, chiffres clés comparés, fil, Mon XV (note,
## énergie, alertes), regard de l'adjoint et accès direct à la tactique et aux remplacements.
## Il n'affiche que la projection `live.direct` du moteur et le modèle : aucun calcul sportif.
const S = preload("res://ui/contextual/skin.gd")
const T = preload("res://theme.gd")
const Terrain2D = preload("res://ui/contextual/match_terrain_2d.gd")

signal niveau_choisi(id: String)
signal reprise_demandee
signal tiroir_demande(titre: String)
## Entracte entre deux temps forts : le manager l'abrège.
signal passer_demande
## Un joueur de Mon XV choisi : le banc s'ouvre sur lui.
signal joueur_choisi(poste: int)
## Score du dernier fait joué sur le terrain (le moteur a parfois une minute d'avance).
signal score_joue(score: Array)

## Chiffres clés sous le terrain (le reste dans l'onglet « Chiffres »).
const CLES := ["possession", "occupation", "plaquages", "franchissements", "penalites"]
## Chiffres qui prennent la place d'un chiffre clé encore vide.
const RELAIS := ["metres", "melees", "touches", "recuperations", "en_avant"]
const ONGLETS := ["Le fil", "Mon XV", "Chiffres"]
const FATIGUE := 55
const EPUISE := 40

var terrain: Terrain2D
var etat: Label
var niveau: OptionButton
var fil: VBoxContainer
var chiffres: VBoxContainer
var tableau: VBoxContainer
var xv: VBoxContainer
var adjoint: VBoxContainer
var adjoint_cadre: Control
var alertes: VBoxContainer
var domination: Domination
var arret: PanelContainer
var arret_titre: Label
var arret_texte: Label
var onglet := "Le fil"
var _onglets: Dictionary = {}
var _pages: Dictionary = {}
var _niveaux: Array = []
var _cle := ""
var _densite := 0.5
var _arret: Dictionary = {}
var entracte: Label
var passer: Button
var _entracte := ["", false]
var _dernier: Array = []
var _lignes: Array = []
## Alertes de Mon XV (fatigue, blessure, carton) : pour l'adjoint et les tests.
var alertes_xv: Array[Dictionary] = []

## Domination minute par minute (`direct.domination`) : barres au-dessus de l'axe pour l'équipe
## qui reçoit, au-dessous pour l'autre, mi-temps et points marqués en repère.
class Domination extends Control:
	const S = preload("res://ui/contextual/skin.gd")
	const T = preload("res://theme.gd")
	var minutes: Array = []
	var mi_temps: Variant = null
	var reperes: Array = []
	var couleurs: Array[Color] = [Color("b8343c"), Color("e9e6d6")]
	var sigles: Array = ["", ""]
	var densite := 0.5

	func _draw() -> void:
		var police: Font = T.DISPLAY
		var corps := roundi(maxf(12.0, 24.0 * densite))
		var marge := Vector2(maxf(24.0, 64.0 * densite), corps * 0.6)
		var zone := Rect2(Vector2(marge.x, marge.y), size - Vector2(marge.x + 6.0 * densite, marge.y * 2.0))
		if zone.size.x < 40.0 or zone.size.y < 20.0: return
		var milieu := zone.position.y + zone.size.y * 0.5
		# Échelle qui s'élargit avec le match (20, 40, 60 puis 80 minutes) : la courbe se lit dès
		# les premières minutes au lieu d'occuper un coin d'un axe de 80 minutes.
		var fin := clampi(int(ceil(float(minutes.size() + 2) / 20.0)) * 20, 20, 80)
		fin = maxi(fin, minutes.size())
		var pas := zone.size.x / float(fin)
		draw_rect(zone, Color(1, 1, 1, 0.03))
		draw_line(Vector2(zone.position.x, milieu), Vector2(zone.end.x, milieu), Color(S.MUTED, 0.45), 1.0)
		var graduation := 5 if fin <= 20 else 10 if fin <= 40 else 20
		for repere in range(graduation, fin, graduation):
			var x := zone.position.x + float(repere) * pas
			draw_dashed_line(Vector2(x, zone.position.y), Vector2(x, zone.end.y), Color(S.MUTED, 0.5 if repere == 40 else 0.25), 1.0, 4.0)
			draw_string(police, Vector2(x - 20.0, zone.end.y + corps * 0.55), "%d'" % repere, HORIZONTAL_ALIGNMENT_CENTER, 40.0, maxi(9, roundi(corps * 0.55)), Color(S.MUTED, 0.7))
		for cote in 2:
			draw_string(police, Vector2(0, milieu + (-zone.size.y * 0.22 if cote == 0 else zone.size.y * 0.22 + corps * 0.7)), str(sigles[cote]), HORIZONTAL_ALIGNMENT_LEFT, marge.x - 4.0, corps, couleurs[cote].lightened(0.15))
		for n in minutes.size():
			var v := clampf(float(minutes[n]) / 100.0, -1.0, 1.0)
			if absf(v) < 0.02: continue
			var h := v * zone.size.y * 0.5
			if absf(h) < 3.0: h = signf(v) * 3.0
			var barre := Rect2(Vector2(zone.position.x + n * pas + pas * 0.12, milieu - maxf(h, 0.0)), Vector2(maxf(1.0, pas * 0.76), absf(h)))
			draw_rect(barre, Color(couleurs[0 if v > 0.0 else 1], 0.92))
		# Points marqués : un jalon à la minute, du côté de l'équipe qui marque.
		for repere: Dictionary in reperes:
			if str(repere.get("kind", "")) == "card": continue
			var m := float(repere.get("minute", 0))
			var cote := int(repere.get("equipe", 0))
			var ou := Vector2(zone.position.x + (m - 0.5) * pas, zone.position.y + 4.0 * densite if cote == 0 else zone.end.y - 4.0 * densite)
			draw_circle(ou, maxf(3.0, 8.0 * densite), couleurs[cote])
			draw_arc(ou, maxf(3.0, 8.0 * densite), 0.0, TAU, 12, S.TEXT, 1.0, true)
		if not minutes.is_empty():
			var x := zone.position.x + minutes.size() * pas
			draw_line(Vector2(x, zone.position.y), Vector2(x, zone.end.y), S.GOLD, maxf(1.5, 3.0 * densite))

## Barre comparée d'un chiffre : valeurs des deux équipes et parts de la barre.
class Barre extends Control:
	const S = preload("res://ui/contextual/skin.gd")
	var valeurs: Array = [0, 0]
	var couleurs: Array[Color] = [Color("b8343c"), Color("e9e6d6")]
	var densite := 0.5

	func _draw() -> void:
		var a := maxf(0.0, float(valeurs[0]))
		var b := maxf(0.0, float(valeurs[1]))
		var h := maxf(4.0, 12.0 * densite)
		var y := (size.y - h) * 0.5
		draw_rect(Rect2(0, y, size.x, h), Color(1, 1, 1, 0.08))
		if a + b <= 0.0: return
		var part := a / (a + b)
		draw_rect(Rect2(0, y, size.x * part - 1.0, h), couleurs[0])
		draw_rect(Rect2(size.x * part + 1.0, y, size.x * (1.0 - part) - 1.0, h), couleurs[1])

## Énergie d'un joueur (condition du moteur, 0 à 100).
class Energie extends Control:
	const S = preload("res://ui/contextual/skin.gd")
	var valeur := 100.0
	var densite := 0.5

	func _draw() -> void:
		var h := maxf(5.0, 12.0 * densite)
		var y := (size.y - h) * 0.5
		draw_rect(Rect2(0, y, size.x, h), Color(1, 1, 1, 0.1))
		var teinte := Color("7fbf86") if valeur >= 70.0 else (S.GOLD if valeur >= 55.0 else Color("e0703f"))
		draw_rect(Rect2(0, y, size.x * clampf(valeur / 100.0, 0.0, 1.0), h), teinte)

## Échelle de l'interface, comme les autres écrans du jeu (immersive08/components.gd) :
## les tailles sont écrites pour 2560×1440 et réduites jusqu'à la moitié en 1280×720.
static func densite_pour(taille: Vector2) -> float:
	return clampf(minf(taille.y / 1440.0, taille.x / 2560.0), 0.5, 1.0)

func px(valeur: float) -> int:
	return roundi(valeur * _densite)

func _texte(texte: String, taille: float, couleur: Color, retour: bool = false, titre: bool = false) -> Label:
	var etiquette := S.wrap(texte, px(taille), couleur) if retour else S.label(texte, px(taille), couleur)
	etiquette.add_theme_font_size_override("font_size", px(taille))
	if titre: etiquette.add_theme_font_override("font", T.DISPLAY)
	return etiquette

func _bouton(texte: String, action: Callable, actif: bool = true, principal: bool = false) -> Button:
	var bouton := S.button(texte, action, actif, principal)
	bouton.custom_minimum_size.y = px(68)
	bouton.add_theme_font_size_override("font_size", px(26))
	return bouton

func _titre(texte: String) -> Label:
	var etiquette := _texte(texte, 26, S.GOLD, false, true)
	etiquette.uppercase = true
	return etiquette

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
	# Le terrain garde sa lecture (places, file des faits) d'une échelle à l'autre.
	var ancien := terrain
	if ancien != null and ancien.get_parent() != null: ancien.get_parent().remove_child(ancien)
	for enfant in get_children():
		remove_child(enfant)
		enfant.queue_free()
	_cle = ""
	var page := S.G.v(px(16))
	S.full(page)
	add_child(page)
	# En-tête : où est le ballon, l'entracte et de quoi l'abréger, le niveau des temps forts.
	var entete := S.G.h(px(20))
	page.add_child(entete)
	etat = _texte("", 34, S.GOLD, false, true)
	etat.name = "MatchBetweenState"
	etat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etat.clip_text = true
	S.G.fill(etat)
	entete.add_child(etat)
	entracte = _texte("", 26, S.TEXT)
	entracte.name = "MatchBetweenInterval"
	entete.add_child(entracte)
	passer = _bouton("PASSER  ›", func(): passer_demande.emit())
	passer.name = "MatchBetweenSkip"
	passer.custom_minimum_size = Vector2(px(220), px(64))
	passer.tooltip_text = "Aller tout de suite au prochain temps fort."
	passer.set_meta("contextual_enabled", true)
	entete.add_child(passer)
	montrer_entracte(_entracte[0], _entracte[1], true)
	entete.add_child(_texte("Temps forts", 26, S.MUTED))
	niveau = OptionButton.new()
	niveau.name = "MatchHighlightLevel"
	niveau.custom_minimum_size = Vector2(px(380), px(64))
	niveau.add_theme_font_size_override("font_size", px(26))
	niveau.get_popup().add_theme_font_size_override("font_size", px(26))
	niveau.set_meta("contextual_enabled", true)
	niveau.item_selected.connect(func(index: int): if index >= 0 and index < _niveaux.size(): niveau_choisi.emit(str(_niveaux[index].get("id", ""))))
	entete.add_child(niveau)
	var corps := S.G.h(px(20))
	S.G.fill(corps, true)
	page.add_child(corps)
	# Colonne principale : le terrain, puis la domination et les chiffres clés.
	var gauche := S.G.v(px(16))
	S.G.fill(gauche, true, 1.85)
	corps.add_child(gauche)
	var cadre_terrain := S.panel(gauche, px(10))
	S.G.fill(cadre_terrain.get_parent().get_parent(), true, 1.0)
	terrain = ancien if ancien != null else Terrain2D.new()
	terrain.densite = _densite
	terrain.custom_minimum_size = Vector2(320, 180)
	S.G.fill(terrain, true)
	cadre_terrain.add_child(terrain)
	var bas := S.G.h(px(20))
	gauche.add_child(bas)
	var cadre_domination := S.panel(bas, px(14))
	S.G.fill(cadre_domination.get_parent().get_parent(), false, 1.15)
	cadre_domination.add_child(_titre("Domination"))
	domination = Domination.new()
	domination.name = "MatchBetweenMomentum"
	domination.densite = _densite
	domination.custom_minimum_size = Vector2(0, px(150))
	domination.tooltip_text = "Qui domine, minute par minute : occupation, possession, points et franchissements."
	domination.mouse_filter = Control.MOUSE_FILTER_PASS
	S.G.fill(domination, true)
	cadre_domination.add_child(domination)
	var cadre_chiffres := S.panel(bas, px(14))
	S.G.fill(cadre_chiffres.get_parent().get_parent(), false, 1.0)
	chiffres = S.G.v(px(2))
	chiffres.name = "MatchBetweenFigures"
	cadre_chiffres.add_child(chiffres)
	# Colonne de droite : onglets (fil, Mon XV, chiffres complets), puis l'adjoint.
	var droite := S.G.v(px(16))
	droite.custom_minimum_size.x = px(720)
	S.G.fill(droite, true, 1.0)
	corps.add_child(droite)
	var cadre_onglets := S.panel(droite, px(16))
	S.G.fill(cadre_onglets.get_parent().get_parent(), true, 1.0)
	var barre_onglets := S.G.h(px(8))
	cadre_onglets.add_child(barre_onglets)
	_onglets.clear()
	_pages.clear()
	for titre: String in ONGLETS:
		var bouton := _bouton(titre.to_upper(), func(): choisir_onglet(titre))
		bouton.name = "MatchBetweenTab" + titre.replace(" ", "")
		bouton.custom_minimum_size.y = px(58)
		bouton.set_meta("contextual_enabled", true)
		S.G.fill(bouton)
		barre_onglets.add_child(bouton)
		_onglets[titre] = bouton
	fil = S.G.scroll(cadre_onglets)
	fil.name = "MatchBetweenFeed"
	fil.add_theme_constant_override("separation", px(10))
	_pages["Le fil"] = fil.get_parent()
	xv = S.G.scroll(cadre_onglets)
	xv.name = "MatchBetweenSquad"
	xv.add_theme_constant_override("separation", px(4))
	_pages["Mon XV"] = xv.get_parent()
	tableau = S.G.scroll(cadre_onglets)
	tableau.name = "MatchBetweenTable"
	tableau.add_theme_constant_override("separation", px(4))
	_pages["Chiffres"] = tableau.get_parent()
	for defilant: ScrollContainer in _pages.values():
		defilant.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		S.G.fill(defilant, true)
	choisir_onglet(onglet)
	adjoint = S.panel(droite, px(16))
	adjoint.name = "MatchBetweenAdvice"
	adjoint_cadre = adjoint.get_parent().get_parent()
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
	arret_titre = _texte("", 44, S.GOLD, false, true)
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
	if not terrain.fait_joue.is_connected(_fait_joue): terrain.fait_joue.connect(_fait_joue)

func choisir_onglet(titre: String) -> void:
	if not titre in ONGLETS: return
	onglet = titre
	for nom: String in _pages: (_pages[nom] as Control).visible = nom == titre
	for nom: String in _onglets:
		var bouton: Button = _onglets[nom]
		if nom == titre: S.selected(bouton, S.GOLD)
		else:
			for etat_bouton in ["normal", "hover", "pressed"]: bouton.add_theme_stylebox_override(etat_bouton, S.G.T.box(S.PANEL, 4, Color("66745e")))
			bouton.add_theme_color_override("font_color", S.TEXT)

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
	terrain.camp = int(direct.get("camp", -1))
	terrain.regler_equipes(equipes)
	# Le terrain rejoue les faits que le joueur peut voir : rien au-delà du journal montré.
	terrain.alimenter(direct.get("deroule", []), mini(live.get("events", []).size(), int(direct.get("borne", live.get("events", []).size()))))
	terrain.queue_redraw()
	_etat(live, direct, equipes)
	_niveaux = direct.get("niveaux", [])
	if niveau.item_count != _niveaux.size():
		niveau.clear()
		for item: Dictionary in _niveaux: niveau.add_item(str(item.get("label", "")))
	for index in _niveaux.size():
		if _niveaux[index].get("id") == direct.get("niveau") and niveau.selected != index: niveau.select(index)
	var dom: Dictionary = direct.get("domination", {}) if direct.get("domination") is Dictionary else {}
	domination.minutes = dom.get("minutes", [])
	domination.mi_temps = dom.get("miTemps")
	domination.reperes = direct.get("reperes", [])
	domination.couleurs = terrain.couleurs.duplicate()
	domination.sigles = [S.G.club_abbr(equipes[0]) if equipes.size() > 0 and equipes[0] is Dictionary else "", S.G.club_abbr(equipes[1]) if equipes.size() > 1 and equipes[1] is Dictionary else ""]
	domination.queue_redraw()
	# Conseil de l'adjoint et composition tels qu'ils étaient avant la borne : rien d'un temps fort à venir.
	var passe := _passe(model, live, direct)
	var conseil: Variant = passe.conseil
	var cle := JSON.stringify([direct.get("fil", []), direct.get("tableau", []), direct.get("chiffres", []), conseil, direct.get("notes", {}), direct.get("cartons", []),
		passe.lineup, direct.get("statsRows", []), live.get("paused", false), live.get("finished", false), terrain.couleurs])
	if cle == _cle: return
	_cle = cle
	_lignes = direct.get("fil", [])
	_remplir_fil()
	_remplir_chiffres(direct, live)
	_remplir_xv(passe.lineup, direct)
	_remplir_adjoint(conseil, live, direct, appliquer)

func _etat(live: Dictionary, direct: Dictionary, equipes: Array) -> void:
	var possession: Variant = direct.get("possession")
	if live.get("finished", false): etat.text = "MATCH TERMINÉ"
	elif live.get("atBreak", false): etat.text = "MI-TEMPS"
	elif (possession is float or possession is int) and equipes.size() >= 2:
		var cote := clampi(int(possession), 0, 1)
		etat.text = "%s · ballon %s" % [S.G.club_name(equipes[cote]).to_upper(), _zone(float(direct.get("zone", {}).get("x", 50.0)), cote)]
	else: etat.text = "LE MATCH"

## Un fait vient d'être joué sur le terrain : le fil le montre, le score le suit.
func _fait_joue(item: Dictionary) -> void:
	_remplir_fil()
	var marque: Variant = item.get("score")
	if marque is Array and (marque as Array).size() == 2: score_joue.emit(marque)

## Score à montrer tant que le terrain rejoue des faits en retard sur le moteur, sinon vide.
## Minute à afficher tant que le terrain rejoue des faits en retard sur le moteur (« 1′ »), sinon vide :
## l'horloge du bandeau suit ce que montre le terrain, comme le score.
func horloge_differee() -> String:
	if terrain == null or not terrain.en_retard(): return ""
	return terrain.horloge_montree()

func score_differe() -> Array:
	if terrain == null or not terrain.en_retard() or terrain.joue.is_empty(): return []
	var marque: Variant = terrain.joue.get("score")
	return marque if marque is Array and (marque as Array).size() == 2 else []

func _remplir_fil() -> void:
	if not is_instance_valid(fil): return
	S.clear(fil)
	# Une ligne n'entre au fil qu'une fois son fait joué sur le terrain.
	var visibles: Array = []
	for entree: Dictionary in _lignes:
		var i := int(entree.get("i", -1))
		var prochain := terrain.prochain_i()
		if prochain >= 0 and i >= prochain: continue
		visibles.append(entree)
	for index in range(visibles.size() - 1, -1, -1):
		var entree: Dictionary = visibles[index]
		var dernier := index == visibles.size() - 1
		var ligne := S.G.h(px(12))
		ligne.set_meta("i", int(entree.get("i", -1)))
		var pastille := ColorRect.new()
		pastille.custom_minimum_size = Vector2(px(8), 0)
		var equipe := int(entree.get("equipe", -1)) if entree.get("equipe") != null else -1
		pastille.color = terrain.couleurs[equipe] if equipe in [0, 1] else Color(S.MUTED, 0.4)
		ligne.add_child(pastille)
		var heure := _texte(str(entree.get("horloge", "")), 26, S.GOLD if dernier else S.MUTED, false, true)
		heure.custom_minimum_size.x = px(70)
		ligne.add_child(heure)
		var texte := _texte(str(entree.get("texte", "")), 28 if dernier else 26, S.TEXT if dernier else S.MUTED, true)
		texte.max_lines_visible = 3 if dernier else 2
		texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		S.G.fill(texte)
		ligne.add_child(texte)
		fil.add_child(ligne)
	if visibles.is_empty(): fil.add_child(_texte("Le coup d’envoi approche.", 26, S.MUTED, true))

func _valeur(rang: Dictionary, cote: int) -> String:
	var valeurs: Array = rang.get("valeurs", [0, 0])
	if rang.get("vide", false): return "—"
	var texte := str(int(valeurs[cote])) + str(rang.get("unite", ""))
	if rang.get("sur") is Array: texte += "/%d" % int(rang.sur[cote])
	return texte

func _ligne_chiffre(parent: Control, rang: Dictionary) -> void:
	var ligne := S.G.h(px(12))
	ligne.custom_minimum_size.y = px(40)
	var titre := _texte(str(rang.get("label", "")), 26, S.MUTED)
	titre.clip_text = true
	titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titre.custom_minimum_size.x = px(150)
	S.G.fill(titre, false, 1.2)
	ligne.add_child(titre)
	var a := _texte(_valeur(rang, 0), 28, S.TEXT, false, true)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a.custom_minimum_size.x = px(78)
	ligne.add_child(a)
	var barre := Barre.new()
	barre.valeurs = rang.get("valeurs", [0, 0]) if not rang.get("vide", false) else [0, 0]
	barre.couleurs = terrain.couleurs.duplicate()
	barre.densite = _densite
	barre.custom_minimum_size = Vector2(px(90), px(30))
	S.G.fill(barre, false, 1.0)
	ligne.add_child(barre)
	var b := _texte(_valeur(rang, 1), 28, S.TEXT, false, true)
	b.custom_minimum_size.x = px(78)
	ligne.add_child(b)
	parent.add_child(ligne)

func _remplir_chiffres(direct: Dictionary, live: Dictionary) -> void:
	S.clear(chiffres)
	S.clear(tableau)
	var rangs: Array = direct.get("tableau", [])
	# Cinq chiffres clés : d'abord ceux qui disent déjà quelque chose (une stat encore vide en
	# début de match cède sa place), sinon les libellés sans valeur (« — »).
	var par_cle := {}
	for rang: Dictionary in rangs: par_cle[str(rang.get("cle", ""))] = rang
	var choisis: Array = []
	for cle: String in CLES + RELAIS:
		if par_cle.has(cle) and not par_cle[cle].get("vide", false) and choisis.size() < CLES.size(): choisis.append(par_cle[cle])
	for cle: String in CLES:
		if par_cle.has(cle) and par_cle[cle].get("vide", false) and choisis.size() < CLES.size(): choisis.append(par_cle[cle])
	for rang: Dictionary in choisis: _ligne_chiffre(chiffres, rang)
	var equipes: Array = live.get("teams", [])
	var entete := S.G.h(px(12))
	for cote in 2:
		var nom := _texte(S.G.club_abbr(equipes[cote]) if equipes.size() > cote and equipes[cote] is Dictionary else "", 26, terrain.couleurs[cote].lightened(0.2), false, true)
		nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if cote == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		S.G.fill(nom)
		entete.add_child(nom)
	tableau.add_child(entete)
	for rang: Dictionary in rangs: _ligne_chiffre(tableau, rang)
	# Chiffres du moteur qui ne se comparent pas en barre (tirs, cartons).
	for rang: Dictionary in direct.get("statsRows", []):
		if not str(rang.get("label", "")) in ["Cartons jaunes", "Tirs de pénalité", "Transformations", "Dont non disputées"]: continue
		var ligne := S.G.h(px(12))
		var titre := _texte(str(rang.get("label", "")), 26, S.MUTED)
		S.G.fill(titre)
		ligne.add_child(titre)
		ligne.add_child(_texte("%s  —  %s" % [str(rang.get("home", "")), str(rang.get("away", ""))], 28, S.TEXT, false, true))
		tableau.add_child(ligne)

## Mon XV : numéro, nom, note du match, énergie et alertes (fatigue, blessure, carton).
func _remplir_xv(joueurs: Array, direct: Dictionary) -> void:
	S.clear(xv)
	alertes_xv.clear()
	var notes: Dictionary = direct.get("notes", {}) if direct.get("notes") is Dictionary else {}
	var cartons: Dictionary = {}
	for carton: Variant in direct.get("cartons", []):
		if carton is Dictionary: cartons[str(carton.get("id", ""))] = carton
	if joueurs.is_empty():
		xv.add_child(_texte("Composition indisponible.", 26, S.MUTED, true))
		return
	var entete := S.G.h(px(10))
	for colonne in [["N°", 50], ["Joueur", 0], ["Note", 80], ["Énergie", 170]]:
		var titre := _texte(str(colonne[0]), 22, S.MUTED)
		if int(colonne[1]) > 0: titre.custom_minimum_size.x = px(colonne[1])
		else: S.G.fill(titre)
		entete.add_child(titre)
	xv.add_child(entete)
	for poste in joueurs.size():
		var joueur: Variant = joueurs[poste]
		var ligne := Button.new()
		ligne.name = "MatchBetweenPlayer%d" % (poste + 1)
		ligne.flat = true
		ligne.custom_minimum_size.y = px(52)
		ligne.focus_mode = Control.FOCUS_ALL
		ligne.set_meta("contextual_enabled", true)
		ligne.pressed.connect(func(): joueur_choisi.emit(poste))
		var rangee := S.G.h(px(10))
		rangee.mouse_filter = Control.MOUSE_FILTER_IGNORE
		S.full(rangee)
		ligne.add_child(rangee)
		var numero := _texte(str(poste + 1), 28, S.GOLD, false, true)
		numero.custom_minimum_size.x = px(50)
		rangee.add_child(numero)
		if not joueur is Dictionary:
			rangee.add_child(_texte("Poste vacant", 26, S.MUTED))
			xv.add_child(ligne)
			continue
		var id := str(joueur.get("id", ""))
		var nom := _texte(str(joueur.get("name", "")), 26, S.TEXT)
		nom.clip_text = true
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		S.G.fill(nom)
		rangee.add_child(nom)
		var fiche: Dictionary = notes.get(id, {}) if notes.get(id) is Dictionary else {}
		var note := float(fiche.get("note", 6.0))
		var etiquette_note := _texte("%.1f" % note, 28, Color("9fd5a6") if note >= 7.0 else (Color("e88d6a") if note < 5.5 else S.TEXT), false, true)
		etiquette_note.custom_minimum_size.x = px(80)
		etiquette_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rangee.add_child(etiquette_note)
		var condition := float(joueur.get("condition", 100))
		var energie := Energie.new()
		energie.valeur = condition
		energie.densite = _densite
		energie.custom_minimum_size = Vector2(px(100), px(30))
		energie.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rangee.add_child(energie)
		var pourcent := _texte("%d %%" % roundi(condition), 22, S.MUTED)
		pourcent.custom_minimum_size.x = px(62)
		rangee.add_child(pourcent)
		var alerte := ""
		if int(joueur.get("injury", 0)) > 0: alerte = "blessé"
		elif cartons.has(id): alerte = "carton jaune, retour %s′" % str(cartons[id].get("retour", "")) if cartons[id].get("retour") != null else "exclu"
		elif condition < EPUISE: alerte = "épuisé"
		elif condition < FATIGUE: alerte = "fatigué"
		var detail := "%d · %s · %s\nNote %.1f (%d action%s du match)" % [poste + 1, str(joueur.get("pos", "")), str(joueur.get("name", "")), note, int(fiche.get("faits", 0)), "s" if int(fiche.get("faits", 0)) > 1 else ""]
		if not alerte.is_empty():
			alertes_xv.append({"poste": poste, "id": id, "nom": str(joueur.get("name", "")), "alerte": alerte, "condition": condition})
			var marque := _texte(alerte.to_upper(), 20, Color("f0a070") if alerte != "fatigué" else S.GOLD, false, true)
			rangee.add_child(marque)
			detail += "\n" + alerte.capitalize()
		ligne.tooltip_text = detail + "\nCliquer : ouvrir le banc sur ce joueur."
		xv.add_child(ligne)

## L'adjoint : alertes de Mon XV d'abord, puis son regard sur les consignes, et les accès directs.
func _remplir_adjoint(conseil: Variant, live: Dictionary, direct: Dictionary, appliquer: Callable) -> void:
	S.clear(adjoint)
	adjoint_cadre.visible = not live.get("finished", false)
	adjoint.add_child(_titre("Le regard de l’adjoint"))
	var lignes := 0
	var graves := alertes_xv.filter(func(a: Dictionary): return a.alerte != "fatigué")
	var fatigues := alertes_xv.filter(func(a: Dictionary): return a.alerte == "fatigué")
	for alerte: Dictionary in (graves + fatigues).slice(0, 2):
		var texte := "N° %d %s : %s." % [int(alerte.poste) + 1, str(alerte.nom), str(alerte.alerte)]
		if str(alerte.alerte) in ["épuisé", "fatigué"]: texte = "N° %d %s : %d %% d’énergie, à surveiller." % [int(alerte.poste) + 1, str(alerte.nom), roundi(float(alerte.condition))]
		if str(alerte.alerte) == "épuisé": texte = "N° %d %s est à bout (%d %%) : un remplacement s’impose." % [int(alerte.poste) + 1, str(alerte.nom), roundi(float(alerte.condition))]
		var etiquette := _texte(texte, 26, Color("f0b080"), true)
		etiquette.max_lines_visible = 2
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		etiquette.tooltip_text = texte
		etiquette.mouse_filter = Control.MOUSE_FILTER_PASS
		adjoint.add_child(etiquette)
		lignes += 1
	var raisons: Array = []
	if conseil is Dictionary:
		for raison in [conseil.get("attackReason", ""), conseil.get("defenceReason", "")]:
			if not str(raison).is_empty(): raisons.append(str(raison))
	var lecture := _lecture(direct)
	if not lecture.is_empty(): raisons.push_front(lecture)
	for raison: String in raisons.slice(0, maxi(1, (2 if _densite < 0.7 else 3) - lignes)):
		var texte := _texte(raison, 26, S.TEXT, true)
		# Retour à la ligne (deux lignes, trois sur grand écran) ; le texte entier reste en infobulle.
		texte.max_lines_visible = 2 if _densite < 0.7 else 3
		texte.tooltip_text = raison
		texte.mouse_filter = Control.MOUSE_FILTER_PASS
		texte.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		adjoint.add_child(texte)
	var actions := S.G.h(px(12))
	adjoint.add_child(actions)
	var tactique := _bouton("TACTIQUE", func(): tiroir_demande.emit("Tactique"))
	tactique.name = "MatchBetweenTactics"
	tactique.tooltip_text = "Consignes d’attaque et de défense (le match se met en pause)."
	actions.add_child(tactique)
	var banc := _bouton("REMPLACEMENTS", func(): tiroir_demande.emit("Banc"))
	banc.name = "MatchBetweenBench"
	banc.tooltip_text = "Ouvrir le banc (le match se met en pause)."
	actions.add_child(banc)
	# Le bouton n'apparaît que si l'adjoint propose autre chose que les consignes en place.
	if conseil is Dictionary and (conseil.get("attackChanged", false) or conseil.get("defenceChanged", false)):
		var possible: bool = conseil.get("canAct", false) and conseil.get("defenceAvailable", false)
		var bouton := _bouton("APPLIQUER", func(): appliquer.call(conseil), possible, true)
		bouton.name = "MatchBetweenApplyAdvice"
		bouton.tooltip_text = "Appliquer les consignes proposées." if possible else "Mettez le match en pause pour modifier vos consignes."
		S.G.fill(bouton)
		actions.add_child(bouton)

## Relevés successifs (taille du journal, composition, conseil de l'adjoint) : l'écran montre le
## dernier pris quand le journal s'arrêtait avant la borne du moteur (`direct.borne`).
var _releves: Array = []
func _passe(model: Dictionary, live: Dictionary, direct: Dictionary) -> Dictionary:
	var n: int = live.get("events", []).size()
	var actuel := {"n": n, "lineup": live.get("lineup", []), "conseil": model.get("decisions", {}).get("liveAdvice")}
	if _releves.is_empty() or int(_releves[-1].n) < n: _releves.append(actuel)
	elif int(_releves[-1].n) == n: _releves[-1] = actuel
	else: _releves = [actuel]
	while _releves.size() > 60: _releves.remove_at(0)
	var borne := int(direct.get("borne", n))
	var choisi: Dictionary = {}
	for releve: Dictionary in _releves:
		if int(releve.n) <= borne: choisi = releve
	# Aucun relevé assez ancien : la composition sans alerte nouvelle, pas de conseil.
	if choisi.is_empty(): return {"lineup": _releves[0].lineup, "conseil": null}
	return choisi

## Une phrase tirée des chiffres du moteur : qui domine depuis cinq minutes, la discipline.
func _lecture(direct: Dictionary) -> String:
	var camp := int(direct.get("camp", -1))
	if not camp in [0, 1]: return ""
	var minutes: Array = direct.get("domination", {}).get("minutes", []) if direct.get("domination") is Dictionary else []
	if minutes.size() >= 5:
		var somme := 0.0
		for v: Variant in minutes.slice(minutes.size() - 5): somme += float(v)
		var nous := somme / 5.0 * (1.0 if camp == 0 else -1.0)
		if nous <= -35.0: return "L’adversaire nous fait reculer depuis cinq minutes : il faut sortir de notre camp."
		if nous >= 35.0: return "On domine depuis cinq minutes : il faut concrétiser cette pression."
	for rang: Variant in direct.get("tableau", []):
		if rang is Dictionary and str(rang.get("cle", "")) == "penalites":
			var v: Array = rang.get("valeurs", [0, 0])
			if int(v[camp]) >= int(v[1 - camp]) + 3: return "Déjà %d pénalités concédées : attention à la discipline." % int(v[camp])
	return ""

## Entracte : texte (« Prochaine action dans 6 s ») et bouton « Passer ».
func montrer_entracte(texte: String, bouton: bool, force: bool = false) -> void:
	if not force and _entracte[0] == texte and _entracte[1] == bouton: return
	_entracte = [texte, bouton]
	if not is_instance_valid(entracte): return
	entracte.text = texte
	entracte.visible = not texte.is_empty()
	passer.visible = bouton

func montrer_arret(valeur: Dictionary) -> void:
	_arret = valeur
	if valeur.is_empty():
		arret.hide()
		return
	var titre := "CARTON ROUGE" if valeur.get("rouge", false) else "CARTON JAUNE"
	arret_titre.text = "%s · %s" % [titre, str(valeur.get("horloge", ""))]
	arret_texte.text = str(valeur.get("texte", "")) + "\nLe match est en pause : réorganisez votre équipe si besoin, puis reprenez."
	arret.show()
