extends Control
## Tableau commun du socle des menus.
##
## Un écran déclare ses colonnes et fournit ses lignes ; le tableau s'occupe du
## tri, des groupes, du filtre, du clavier, de la sélection et du défilement.
## Les lignes sont dessinées, pas instanciées : seules celles qui sont visibles
## coûtent quelque chose, que la liste compte 40 joueurs ou 4 000.
##
## Colonne : {id, titre, largeur, souple?, priorite?, align?, triable?,
##   valeur: Callable(ligne) -> Variant        valeur de tri, null = inconnu
##   texte: Callable(ligne) -> String          texte affiché
##   second: Callable(ligne) -> String         précision discrète après le texte
##   couleur: Callable(ligne) -> Color
##   dessin: Callable(zone, rect, ligne)       dessin libre de la cellule
##   vignette: Callable(ligne) -> Control      portrait placé en tête de cellule
##   infobulle: Callable(ligne) -> String, gras?: bool}
## `priorite` : 0 = toujours visible ; plus le nombre est grand, plus la colonne
## est retirée tôt quand la largeur manque.

signal ligne_choisie(ligne: Dictionary)
signal ligne_activee(ligne: Dictionary)
signal tri_change(colonne: String, decroissant: bool)
signal contenu_change(visibles: int, total: int)

const J = preload("res://ui/socle/jetons.gd")

var colonnes: Array = []
var cle := "id"
var tri_colonne := ""
var tri_decroissant := false
var groupe_de := Callable()
var entete_groupe := Callable()
var ordre_groupes: Array = []
var choisie := ""
var message_vide := "Aucune ligne ne correspond."

var _source: Array = []
var _filtre := Callable()
var _elements: Array = []
var _lignes: Array = []
var _hauteur := 0.0
var _defilement := 0.0
var _survol := -1
var _places: Array = []
var _vignettes: Dictionary = {}
var _zone: Zone
var _barre: VScrollBar
var _dernier_tri_ms := 0.0

class Zone extends Control:
	var tableau: Control
	func _draw() -> void: tableau._dessiner_lignes(self)
	func _gui_input(event: InputEvent) -> void: tableau._entree_zone(event)
	func _get_tooltip(at: Vector2) -> String: return tableau._infobulle(at)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and tableau._survol != -1:
			tableau._survol = -1
			queue_redraw()

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_zone = Zone.new()
	_zone.tableau = self
	_zone.name = "Lignes"
	_zone.clip_contents = true
	_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_zone)
	_barre = VScrollBar.new()
	_barre.name = "Defilement"
	_barre.add_theme_stylebox_override("scroll", J.boite(Color(J.RAIL, 0.6), 5))
	for etat_barre: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		_barre.add_theme_stylebox_override(etat_barre, J.boite(J.TEXTE_FAIBLE if etat_barre == "grabber" else J.TEXTE_DOUX, 5))
	_barre.value_changed.connect(func(valeur: float):
		_defilement = valeur
		_placer_vignettes()
		_zone.queue_redraw())
	add_child(_barre)
	resized.connect(_disposer)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

# ---------------------------------------------------------------- données

func definir_lignes(lignes: Array) -> void:
	_source = lignes
	_recalculer()

func definir_filtre(filtre: Callable) -> void:
	_filtre = filtre
	_recalculer()

func definir_colonnes(nouvelles: Array) -> void:
	colonnes = nouvelles
	_disposer()

func trier(colonne: String, decroissant: bool) -> void:
	tri_colonne = colonne
	tri_decroissant = decroissant
	_recalculer()

func lignes_visibles() -> Array:
	return _lignes

func duree_dernier_tri_ms() -> float:
	return _dernier_tri_ms

func choisir(valeur_cle: String, montrer := true) -> void:
	choisie = valeur_cle
	if montrer: _montrer_choisie()
	_zone.queue_redraw()

func _colonne(id: String) -> Dictionary:
	for colonne: Dictionary in colonnes:
		if colonne.id == id: return colonne
	return {}

func _ordonner(lignes: Array) -> Array:
	var colonne := _colonne(tri_colonne)
	if colonne.is_empty() or not colonne.has("valeur"): return lignes
	var valeur: Callable = colonne.valeur
	# Clés précalculées puis tri natif : [clé, identifiant, rang d'origine].
	var connus: Array = []
	var inconnus: Array = []
	for i in lignes.size():
		var v: Variant = valeur.call(lignes[i])
		var id := str(lignes[i].get(cle, ""))
		if v == null or (v is String and v.is_empty()): inconnus.append([id, i])
		elif v is int or v is float: connus.append([float(v), id, i])
		else: connus.append([J.plier(v), id, i])
	connus.sort()
	if tri_decroissant:
		connus.reverse()
		# À valeur égale, l'ordre reste celui des identifiants.
		var debut := 0
		while debut < connus.size():
			var fin := debut
			while fin + 1 < connus.size() and connus[fin + 1][0] == connus[debut][0]: fin += 1
			var gauche := debut
			var droite := fin
			while gauche < droite:
				var echange: Array = connus[gauche]; connus[gauche] = connus[droite]; connus[droite] = echange
				gauche += 1; droite -= 1
			debut = fin + 1
	inconnus.sort()
	var resultat: Array = []
	resultat.resize(lignes.size())
	var n := 0
	for entree: Array in connus: resultat[n] = lignes[entree[2]]; n += 1
	# Une valeur inconnue reste en bas, quel que soit le sens.
	for entree: Array in inconnus: resultat[n] = lignes[entree[1]]; n += 1
	return resultat

func _recalculer() -> void:
	var debut := Time.get_ticks_usec()
	var retenues: Array = []
	for ligne: Dictionary in _source:
		if not _filtre.is_valid() or _filtre.call(ligne): retenues.append(ligne)
	_elements = []
	_lignes = []
	var y := 0.0
	var h_ligne := float(J.px(J.LIGNE_H))
	var h_groupe := float(J.px(J.GROUPE_H))
	if groupe_de.is_valid():
		var lots: Dictionary = {}
		for ligne: Dictionary in retenues:
			var k: Variant = groupe_de.call(ligne)
			if not lots.has(k): lots[k] = []
			lots[k].append(ligne)
		var ordre: Array = ordre_groupes.filter(func(k: Variant): return lots.has(k))
		for k: Variant in lots:
			if k not in ordre: ordre.append(k)
		for k: Variant in ordre:
			var triees := _ordonner(lots[k])
			var titre: Dictionary = entete_groupe.call(k, triees) if entete_groupe.is_valid() else {"titre": str(k), "detail": ""}
			_elements.append({"groupe": true, "y": y, "h": h_groupe, "titre": titre})
			y += h_groupe
			for ligne: Dictionary in triees:
				_elements.append({"groupe": false, "y": y, "h": h_ligne, "ligne": ligne, "rang": _lignes.size()})
				_lignes.append(ligne)
				y += h_ligne
	else:
		for ligne: Dictionary in _ordonner(retenues):
			_elements.append({"groupe": false, "y": y, "h": h_ligne, "ligne": ligne, "rang": _lignes.size()})
			_lignes.append(ligne)
			y += h_ligne
	_hauteur = y
	_dernier_tri_ms = (Time.get_ticks_usec() - debut) / 1000.0
	_disposer()
	contenu_change.emit(_lignes.size(), _source.size())

# ---------------------------------------------------------------- mise en page

func _disposer() -> void:
	if size.x <= 0 or size.y <= 0: return
	var h_entete := float(J.px(J.ENTETE_H))
	var l_barre := float(J.px(10))
	var hauteur_zone := maxf(0.0, size.y - h_entete)
	var defile := _hauteur > hauteur_zone + 0.5
	_barre.visible = defile
	_barre.position = Vector2(size.x - l_barre, h_entete)
	_barre.size = Vector2(l_barre, hauteur_zone)
	_barre.max_value = maxf(_hauteur, hauteur_zone)
	_barre.page = hauteur_zone
	_barre.step = 1.0
	_defilement = clampf(_defilement, 0.0, maxf(0.0, _hauteur - hauteur_zone))
	_barre.set_value_no_signal(_defilement)
	_zone.position = Vector2(0, h_entete)
	_zone.size = Vector2(size.x - (l_barre + J.px(6) if defile else 0.0), hauteur_zone)
	# Colonnes : on retire les moins prioritaires tant que la largeur manque.
	var visibles: Array = colonnes.duplicate()
	var ecart := float(J.px(J.E4))
	var besoin := func(liste: Array) -> float:
		var somme := 0.0
		for colonne: Dictionary in liste: somme += float(J.px(colonne.get("largeur", 80))) + ecart
		return somme - ecart
	while visibles.size() > 1 and besoin.call(visibles) > _zone.size.x:
		var pire := -1
		var indice := -1
		for i in visibles.size():
			var p := int(visibles[i].get("priorite", 0))
			if p > pire: pire = p; indice = i
		if pire <= 0: break
		visibles.remove_at(indice)
	var reste := maxf(0.0, _zone.size.x - besoin.call(visibles))
	var souplesse := 0.0
	for colonne: Dictionary in visibles: souplesse += float(colonne.get("souple", 0))
	_places = []
	var x := 0.0
	for colonne: Dictionary in visibles:
		var largeur := float(J.px(colonne.get("largeur", 80)))
		if souplesse > 0.0: largeur += reste * float(colonne.get("souple", 0)) / souplesse
		_places.append({"colonne": colonne, "x": x, "l": largeur})
		x += largeur + ecart
	_placer_vignettes()
	queue_redraw()
	_zone.queue_redraw()

func colonnes_affichees() -> Array:
	return _places.map(func(place: Dictionary): return place.colonne.id)

func _placer_vignettes() -> void:
	var place: Dictionary = {}
	for candidate: Dictionary in _places:
		if candidate.colonne.has("vignette"): place = candidate
	var vues: Dictionary = {}
	if not place.is_empty():
		var creer: Callable = place.colonne.vignette
		var diametre := float(J.px(J.LIGNE_H - 9))
		for element: Dictionary in _elements:
			if element.groupe: continue
			var haut: float = element.y - _defilement
			if haut + element.h < 0 or haut > _zone.size.y: continue
			var k := str(element.ligne.get(cle, ""))
			var vignette: Control = _vignettes.get(k)
			if vignette == null:
				vignette = creer.call(element.ligne, diametre)
				if vignette == null: continue
				vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_vignettes[k] = vignette
				_zone.add_child(vignette)
			vignette.position = Vector2(place.x, haut + (element.h - diametre) / 2.0).round()
			vignette.visible = true
			vues[k] = true
	for k: String in _vignettes:
		if not vues.has(k): _vignettes[k].visible = false
	if _vignettes.size() > 400:
		for k: String in _vignettes.keys():
			if not vues.has(k):
				_vignettes[k].queue_free()
				_vignettes.erase(k)

func vider_vignettes() -> void:
	for k: String in _vignettes: _vignettes[k].queue_free()
	_vignettes = {}

# ---------------------------------------------------------------- dessin

func _ecrire(sur: CanvasItem, police: Font, taille: int, texte: String, rect: Rect2, couleur: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> float:
	var ligne_base := rect.position.y + (rect.size.y + police.get_ascent(taille) - police.get_descent(taille)) / 2.0
	sur.draw_string(police, Vector2(rect.position.x, ligne_base).round(), texte, align, rect.size.x, taille, couleur)
	return police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

func _draw() -> void:
	var h_entete := float(J.px(J.ENTETE_H))
	var taille := J.px(J.T_PETIT)
	for place: Dictionary in _places:
		var colonne: Dictionary = place.colonne
		var actif: bool = colonne.id == tri_colonne
		var rect := Rect2(place.x, 0, place.l, h_entete - J.px(6))
		var couleur := J.TEXTE if actif else J.TEXTE_FAIBLE
		var titre := str(colonne.get("titre", ""))
		var largeur_titre := J.CORPS.get_string_size(titre, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var a_droite: bool = colonne.get("align", HORIZONTAL_ALIGNMENT_LEFT) == HORIZONTAL_ALIGNMENT_RIGHT
		var fleche := float(J.px(12)) if actif else 0.0
		if a_droite: rect.size.x -= fleche
		_ecrire(self, J.CORPS, taille, titre, rect, couleur, colonne.get("align", HORIZONTAL_ALIGNMENT_LEFT))
		if actif:
			var cx := (rect.end.x + J.px(7)) if a_droite else minf(place.x + largeur_titre + J.px(9), place.x + place.l - J.px(5))
			var cy := rect.position.y + rect.size.y / 2.0
			var d := float(J.px(4))
			var points := PackedVector2Array([Vector2(cx - d, cy - d * 0.6), Vector2(cx + d, cy - d * 0.6), Vector2(cx, cy + d * 0.8)]) if tri_decroissant else PackedVector2Array([Vector2(cx - d, cy + d * 0.6), Vector2(cx + d, cy + d * 0.6), Vector2(cx, cy - d * 0.8)])
			draw_colored_polygon(points, J.OR)
	draw_rect(Rect2(0, h_entete - 1, _zone.size.x, 1), J.TRAIT)
	if has_focus():
		draw_rect(Rect2(0, h_entete - 1, _zone.size.x, maxi(1, J.px(1.5))), J.OR)

func _dessiner_lignes(zone: Control) -> void:
	if _lignes.is_empty():
		_ecrire(zone, J.CORPS, J.px(J.T_CORPS), message_vide, Rect2(0, J.px(J.E4), zone.size.x, J.px(J.LIGNE_H)), J.TEXTE_DOUX)
		return
	var taille := J.px(J.T_CORPS)
	var gras := J.corps_gras()
	for element: Dictionary in _elements:
		var haut: float = element.y - _defilement
		if haut + element.h < 0: continue
		if haut > zone.size.y: break
		if element.groupe:
			var base := Rect2(0, haut + J.px(8), zone.size.x, element.h - J.px(10))
			var largeur := _ecrire(zone, J.TITRE, J.px(J.T_CHIFFRE), str(element.titre.get("titre", "")), base, J.TEXTE)
			var detail := str(element.titre.get("detail", ""))
			if not detail.is_empty():
				_ecrire(zone, J.CORPS, J.px(J.T_PETIT + 1), detail, Rect2(largeur + J.px(J.E3), haut + J.px(11), zone.size.x - largeur - J.px(J.E3), element.h - J.px(10)), J.TEXTE_DOUX)
			zone.draw_rect(Rect2(0, haut + element.h - 1, zone.size.x, 1), J.TRAIT)
			continue
		var ligne: Dictionary = element.ligne
		var est_choisie := str(ligne.get(cle, "")) == choisie
		if est_choisie or element.rang == _survol:
			zone.draw_style_box(J.boite(J.CHOIX if est_choisie else J.SURVOL, 6), Rect2(-J.px(2), haut + 1, zone.size.x + J.px(2), element.h - 2))
		else:
			zone.draw_rect(Rect2(0, haut + element.h - 1, zone.size.x, 1), Color(J.TRAIT, 0.55))
		for place: Dictionary in _places:
			var colonne: Dictionary = place.colonne
			var rect := Rect2(place.x, haut, place.l, element.h)
			if colonne.has("vignette"):
				var retrait := float(J.px(J.LIGNE_H - 9 + J.E3))
				rect.position.x += retrait
				rect.size.x -= retrait
			if colonne.has("dessin"):
				colonne.dessin.call(zone, rect, ligne)
				continue
			var texte := str(colonne.texte.call(ligne)) if colonne.has("texte") else ""
			var couleur: Color = colonne.couleur.call(ligne) if colonne.has("couleur") else (J.TEXTE if colonne.get("gras", false) else J.TEXTE_DOUX)
			var police: Font = gras if colonne.get("gras", false) else J.CORPS
			var align: int = colonne.get("align", HORIZONTAL_ALIGNMENT_LEFT)
			if colonne.has("second") and align == HORIZONTAL_ALIGNMENT_LEFT:
				var second := str(colonne.second.call(ligne))
				var l_second := J.CORPS.get_string_size(second, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x if not second.is_empty() else 0.0
				var dispo := rect.size.x - (l_second + J.px(10) if l_second > 0 else 0.0)
				var l_texte := minf(police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x, maxf(dispo, rect.size.x * 0.6))
				zone.draw_string(police, Vector2(rect.position.x, rect.position.y + (rect.size.y + police.get_ascent(taille) - police.get_descent(taille)) / 2.0).round(), texte, HORIZONTAL_ALIGNMENT_LEFT, l_texte, taille, couleur, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL)
				if l_second > 0 and rect.size.x - l_texte - J.px(10) > J.px(30):
					_ecrire(zone, J.CORPS, taille, second, Rect2(rect.position.x + l_texte + J.px(10), rect.position.y, rect.size.x - l_texte - J.px(10), rect.size.y), J.TEXTE_FAIBLE)
			else:
				_ecrire(zone, police, taille, texte, rect, couleur, align)

# ---------------------------------------------------------------- entrées

func _element_sous(y: float) -> Dictionary:
	var cible := y + _defilement
	for element: Dictionary in _elements:
		if cible >= element.y and cible < element.y + element.h: return element
	return {}

func _infobulle(at: Vector2) -> String:
	var element := _element_sous(at.y)
	if element.is_empty() or element.groupe: return ""
	for place: Dictionary in _places:
		if at.x >= place.x and at.x < place.x + place.l and place.colonne.has("infobulle"):
			return str(place.colonne.infobulle.call(element.ligne))
	return ""

func _defiler(delta: float) -> void:
	_barre.value = clampf(_defilement + delta, 0.0, maxf(0.0, _hauteur - _zone.size.y))

func _entree_zone(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var element := _element_sous(event.position.y)
		var rang := -1 if element.is_empty() or element.groupe else int(element.rang)
		if rang != _survol:
			_survol = rang
			_zone.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _defiler(J.px(J.LIGNE_H) * 3.0); _zone.accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: _defiler(-J.px(J.LIGNE_H) * 3.0); _zone.accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			var element := _element_sous(event.position.y)
			if element.is_empty() or element.groupe: return
			_choisir_rang(int(element.rang), false)
			if event.double_click: ligne_activee.emit(element.ligne)
			_zone.accept_event()

func _choisir_rang(rang: int, montrer := true) -> void:
	if _lignes.is_empty(): return
	rang = clampi(rang, 0, _lignes.size() - 1)
	choisie = str(_lignes[rang].get(cle, ""))
	if montrer: _montrer_choisie()
	_zone.queue_redraw()
	ligne_choisie.emit(_lignes[rang])

func _rang_choisi() -> int:
	for i in _lignes.size():
		if str(_lignes[i].get(cle, "")) == choisie: return i
	return -1

func _montrer_choisie() -> void:
	for i in _elements.size():
		var element: Dictionary = _elements[i]
		if element.groupe or str(element.ligne.get(cle, "")) != choisie: continue
		# La première ligne d'un groupe se montre avec son titre.
		var haut: float = _elements[i - 1].y if i > 0 and _elements[i - 1].groupe else element.y
		if haut < _defilement: _barre.value = haut
		elif element.y + element.h > _defilement + _zone.size.y: _barre.value = element.y + element.h - _zone.size.y
		return

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.position.y < J.px(J.ENTETE_H):
		grab_focus()
		for place: Dictionary in _places:
			if event.position.x >= place.x and event.position.x < place.x + place.l and place.colonne.get("triable", true) and place.colonne.has("valeur"):
				var id := str(place.colonne.id)
				var sens := not tri_decroissant if id == tri_colonne else bool(place.colonne.get("decroissant_d_abord", false))
				trier(id, sens)
				tri_change.emit(id, sens)
				accept_event()
				return
	elif event is InputEventKey and event.pressed:
		var page := maxi(1, int(_zone.size.y / J.px(J.LIGNE_H)) - 1)
		var rang := _rang_choisi()
		match event.keycode:
			KEY_DOWN: _choisir_rang(rang + 1); accept_event()
			KEY_UP: _choisir_rang(maxi(0, rang - 1)); accept_event()
			KEY_PAGEDOWN: _choisir_rang(rang + page); accept_event()
			KEY_PAGEUP: _choisir_rang(maxi(0, rang - page)); accept_event()
			KEY_HOME: _choisir_rang(0); accept_event()
			KEY_END: _choisir_rang(_lignes.size() - 1); accept_event()
			KEY_ENTER, KEY_KP_ENTER:
				if rang >= 0: ligne_activee.emit(_lignes[rang]); accept_event()

func _get_tooltip(at: Vector2) -> String:
	for place: Dictionary in _places:
		if at.x >= place.x and at.x < place.x + place.l and at.y < J.px(J.ENTETE_H):
			return str(place.colonne.get("aide", ""))
	return ""
