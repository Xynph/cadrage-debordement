extends RefCounted
## Bloc « Impact face à l'adversaire » de la Composition (maquette 10-composition-1) : six duels projetés par le staff
## (moteur : decisions.preparation.domains, own / opponent), écart chiffré avec ▲ / ▼ (jamais la couleur seule),
## vigilance physique de la feuille, lecture « au près » et « au large », lien vers le dossier adverse, bulle de Gabi
## qui porte l'avis du staff sur la feuille (selection.staffAdvice).
## Exemple : `Impact.build(app, page, Rect2(1684, 200, 564, 696), "Northmere Blues")`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Selection = preload("res://ui/immersive08/tactics_selection.gd")
const PersonName = preload("res://ui/person_name.gd")
const PORTRAIT = preload("res://guide/coach_portrait.gd")
## Duels dans l'ordre de la maquette : [clé du moteur, libellé, libellé court].
const DUELS := [["scrum", "Mêlée", "mêlée"], ["lineout", "Touche", "touche"], ["power", "Puissance des avants", "puissance"],
	["backs", "Passe et vitesse", "passe et vitesse"], ["kick", "Jeu au pied", "jeu au pied"], ["discipline", "Discipline", "discipline"]]
const PRES := ["scrum", "lineout", "power"]
const LARGE := ["backs", "kick"]

static func build(app: Control, page: Control, zone: Rect2, adversaire: String, choisir: Callable = Callable()) -> Panel:
	var bloc := D.rect(page, zone, Charte.PANNEAU, 0)
	bloc.name = "TacticsImpact"
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	var w := zone.size.x
	Kit.titre(bloc, 22, 34, "Impact face à " + adversaire if not adversaire.is_empty() else "Impact face à l’adversaire", 24, w - 44)
	D.line(bloc, Vector2(22, 46), Vector2(w - 22, 46), Charte.FILET)
	var preparation: Variant = app.model.get("decisions", {}).get("preparation")
	var domaines: Array = preparation.get("domains", []) if preparation is Dictionary else []
	var valeurs := {}
	for domaine: Variant in domaines:
		if domaine is Dictionary: valeurs[str(domaine.get("key", ""))] = domaine
	var y := 74.0
	if valeurs.is_empty():
		var attente := Kit.texte(bloc, 22, y, "Projection du staff livrée la semaine du match.", Charte.IVOIRE_2, w - 44)
		attente.name = "TacticsNoReport"
		y += 30
	else:
		Kit.texte(bloc, 22, y, "Projection du staff" if C.dense() else "Projection du staff · se recalcule à chaque changement", Charte.IVOIRE_2, w - 44, 16)
		y += 14
		for i in DUELS.size():
			_duel(app, bloc, i, y + i * 38, w, DUELS[i], valeurs.get(DUELS[i][0], {}))
		y += DUELS.size() * 38 + 16
	_lignes(app, bloc, y, w, valeurs)
	_gabi(app, bloc, w, zone.size.y, choisir)
	return bloc

static func _nombre(valeur: Variant) -> Variant:
	return float(valeur) if (valeur is int or valeur is float) and is_finite(float(valeur)) else null

## Un duel : ligne entière cliquable vers le dossier adverse de la préparation (survol = fond plus clair).
static func _duel(app: Control, bloc: Control, rang: int, y: float, w: float, duel: Array, domaine: Dictionary) -> void:
	var nous: Variant = _nombre(domaine.get("own"))
	var eux: Variant = _nombre(domaine.get("opponent"))
	var ligne := Button.new()
	ligne.name = "TacticsDuel_" + str(duel[0])
	Kit.styler_ligne(ligne, Charte.PANNEAU)
	bloc.add_child(ligne)
	D.place(ligne, Rect2(14, y, w - 28, 38))
	ligne.pressed.connect(func(): app.Immersive.open_preparation(app, 0))
	if rang > 0: D.line(ligne, Vector2(8, 0), Vector2(w - 36, 0), Charte.PANNEAU_2)
	var barre := 100.0
	var gras := Kit.texte_gras()
	var a := D.text(ligne, 48, 25, G.n(roundi(nous)) if nous != null else "—", 18, Charte.IVOIRE, 700, 38, HORIZONTAL_ALIGNMENT_RIGHT, true)
	a.add_theme_font_override("font", gras)
	a.name = "TacticsDomainOwn"
	if nous != null: D.rect(ligne, Rect2(56 + barre * (1.0 - clampf(nous, 0, 100) / 100.0), 12, barre * clampf(nous, 0, 100) / 100.0, 13), Charte.club_trait(app.accent), 0)
	Kit.texte(ligne, 256, 25, str(duel[1]), Charte.IVOIRE, 190, 18, HORIZONTAL_ALIGNMENT_CENTER)
	if eux != null: D.rect(ligne, Rect2(358, 12, barre * clampf(eux, 0, 100) / 100.0, 13), Charte.IVOIRE_2, 0)
	var b := D.text(ligne, 466, 25, G.n(roundi(eux)) if eux != null else "—", 18, Charte.IVOIRE, 700, 40, HORIZONTAL_ALIGNMENT_LEFT, true)
	b.add_theme_font_override("font", gras)
	b.name = "TacticsDomainOpponent"
	var libelle := "%s : %s contre %s" % [duel[1], a.text, b.text]
	if nous != null and eux != null:
		var ecart := roundi(nous) - roundi(eux)
		var texte := "▲ +%d" % ecart if ecart > 0 else ("▼ −%d" % -ecart if ecart < 0 else "= 0")
		var e := D.text(ligne, w - 36, 25, texte, 18, Charte.IVOIRE if ecart >= 0 else Charte.IVOIRE_2, 700, 70, HORIZONTAL_ALIGNMENT_RIGHT, true)
		e.add_theme_font_override("font", gras)
		e.name = "TacticsDomainGap"
		libelle += " (%s)" % texte
	ligne.accessibility_name = libelle + " · ouvrir le dossier adverse"

## Vigilance (joueurs de la feuille sous 80 % : noms cliquables, fiche + mini-fiche, jamais coupés ; au-delà de deux
## lignes, menu déroulant « + n »), au près, au large, lien vers le dossier adverse.
static func _lignes(app: Control, bloc: Control, y: float, w: float, valeurs: Dictionary) -> void:
	var sous: Array = []
	for slot in 23:
		var person := Selection.occupant(app.model, slot)
		var forme: Variant = person.get("condition")
		if (forme is int or forme is float) and float(forme) < 80: sous.append(person)
	Kit.etiquette(bloc, 22, y + 22, "Vigilance", 120)
	var vigilance := Control.new()
	vigilance.name = "TacticsVigilance"
	vigilance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(vigilance)
	D.place(vigilance, Rect2(150, y, w - 172, 60))
	var hauteur := 36.0
	if sous.is_empty():
		Kit.texte(vigilance, 0, 23, "Aucune alerte physique sur la feuille", Charte.IVOIRE, w - 172)
	else:
		var morceaux: Array = [{"texte":"! %d sous 80 %% :" % sous.size(), "couleur":Charte.D}]
		for i in sous.size():
			if i > 0: morceaux.append({"texte":"·", "couleur":Charte.IVOIRE_2})
			morceaux.append({"texte":Kit.casse(str(sous[i].get("name", "")), true), "joueur":str(sous[i].get("id", ""))})
		var pose := Kit.flux(app, vigilance, 0, 23, w - 172 - 70, morceaux, 17, 24, 2, "TacticsVigilance")
		hauteur = 12.0 + maxf(24.0, Kit.hauteur_ligne(17) + 2) * maxi(1, int(pose.lignes))
		if int(pose.omis) > 0: _autres(app, vigilance, Rect2(w - 172 - 64, 4, 64, 28), sous)
	D.line(bloc, Vector2(22, y + hauteur), Vector2(w - 22, y + hauteur), Charte.PANNEAU_2)
	var lignes: Array = []
	if not valeurs.is_empty():
		lignes.append(["Au près", _resume(valeurs, PRES), "TacticsClose"])
		lignes.append(["Au large", _resume(valeurs, LARGE), "TacticsWide"])
	for i in lignes.size():
		var entree: Array = lignes[i]
		var haut := y + hauteur + i * 34
		Kit.etiquette(bloc, 22, haut + 22, str(entree[0]), 120)
		Kit.texte(bloc, 150, haut + 23, str(entree[1]), Charte.IVOIRE, w - 172).name = str(entree[2])
		D.line(bloc, Vector2(22, haut + 32), Vector2(w - 22, haut + 32), Charte.PANNEAU_2)
	var lien := Kit.lien(bloc, Rect2(16, y + hauteur + lignes.size() * 34 + 6, 0, 34), "Voir le dossier adverse →", func(): app.Immersive.open_preparation(app, 0), "TacticsOpponentFile")
	lien.tooltip_text = "Dossier de préparation : forces et habitudes de l’adversaire"

## Menu déroulant (exception autorisée) des joueurs sous 80 % : chaque entrée ouvre la fiche du joueur.
static func _autres(app: Control, parent: Control, zone: Rect2, joueurs: Array) -> MenuButton:
	var menu := MenuButton.new()
	menu.name = "TacticsVigilanceMore"
	menu.text = "tous ▾"
	menu.flat = true
	menu.add_theme_font_override("font", Charte.texte_moyen())
	menu.add_theme_font_size_override("font_size", maxi(12, C.px(17)))
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: menu.add_theme_color_override(couleur, Charte.IVOIRE)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 2)
	focus.set_border_width_all(2)
	menu.add_theme_stylebox_override("focus", focus)
	var liste := menu.get_popup()
	_styler_menu(liste)
	for i in joueurs.size():
		var forme: Variant = joueurs[i].get("condition")
		liste.add_item("%s · %d %%" % [Kit.casse(str(joueurs[i].get("name", ""))), roundi(float(forme))], i)
	liste.id_pressed.connect(func(index: int): app.navigation_controller.open_entity({"kind":"player", "id":str(joueurs[index].get("id", ""))}))
	parent.add_child(menu)
	D.place(menu, zone)
	return menu

static func _styler_menu(liste: PopupMenu) -> void:
	liste.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU_3, Charte.FILET, 0, 6))
	liste.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 0, 4))
	liste.add_theme_font_override("font", Charte.TEXTE)
	liste.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	liste.add_theme_color_override("font_color", Charte.IVOIRE)
	liste.add_theme_color_override("font_hover_color", Charte.IVOIRE)

static func _resume(valeurs: Dictionary, cles: Array) -> String:
	var morceaux: Array[String] = []
	for duel: Array in DUELS:
		if duel[0] not in cles: continue
		var domaine: Dictionary = valeurs.get(duel[0], {})
		var nous: Variant = _nombre(domaine.get("own"))
		var eux: Variant = _nombre(domaine.get("opponent"))
		if nous == null or eux == null: continue
		var ecart := roundi(nous) - roundi(eux)
		morceaux.append("%s %s" % [duel[2], ("+%d" % ecart) if ecart > 0 else ("−%d" % -ecart if ecart < 0 else "0")])
	if morceaux.is_empty(): return "—"
	var texte := " · ".join(morceaux)
	return texte.left(1).to_upper() + texte.substr(1)

## Bulle de Gabi : l'avis du staff sur la feuille, au plus trois conseils sur deux lignes chacun, jamais coupés en
## « … » ; les deux noms ouvrent la fiche (survol = mini-fiche), « n° X → » montre les candidats du poste.
static func _gabi(app: Control, bloc: Control, w: float, h: float, choisir: Callable) -> void:
	var portrait := 120.0
	var largeur := w - 44 - portrait - 8
	var bulle := D.rect(bloc, Rect2(22, h - 210, largeur, 196), Charte.PANNEAU_2, 0)
	bulle.name = "TacticsStaffAdvice"
	bulle.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.marqueur(bulle, Rect2(6, 10, 4, 24), Charte.club_trait(app.accent))
	Kit.etiquette(bulle, 22, 28, "Gabi · avis du staff", 300)
	var data: Variant = app.model.get("selection", {}).get("staffAdvice")
	var conseils: Array = data.get("conseils", []) if data is Dictionary else []
	var texte_l := largeur - 34
	if data is Dictionary and conseils.is_empty():
		Kit.texte(bulle, 22, 58, "Ton staff valide ta feuille.", Charte.IVOIRE, texte_l).name = "TacticsStaffAdviceAgree"
	elif conseils.is_empty():
		var phrase := "Clique un poste pour voir qui peut le tenir."
		var erreurs: Array = app.model.get("selection", {}).get("errors", [])
		if not erreurs.is_empty(): phrase = "Complète d’abord la feuille : " + str(erreurs[0])
		Kit.flux(app, bulle, 22, 58, texte_l, [{"texte":phrase}], 17, 22, 6, "TacticsStaffAdviceText")
	var interligne := maxf(22.0, Kit.hauteur_ligne(17) + 2)
	var pas := 2 * interligne + 8
	for i in mini(conseils.size(), 2 if C.dense() else 3):
		var conseil: Dictionary = conseils[i]
		var cadre := Control.new()
		cadre.name = "TacticsStaffAdvice%d" % i
		cadre.mouse_filter = Control.MOUSE_FILTER_PASS
		cadre.tooltip_text = str(conseil.get("texte", ""))
		cadre.set_meta("court", str(conseil.get("court", "")))
		bulle.add_child(cadre)
		D.place(cadre, Rect2(22, 36 + i * pas, texte_l, pas))
		var slot := int(conseil.get("slot", -1))
		var morceaux: Array = []
		if conseil.has("staffId") and conseil.has("chosenId"):
			morceaux.append({"texte":Kit.casse(str(conseil.get("staffName", "")), true), "joueur":str(conseil.staffId)})
			morceaux.append({"texte":"plutôt que"})
			morceaux.append({"texte":Kit.casse(str(conseil.get("chosenName", "")), true), "joueur":str(conseil.chosenId)})
			if slot >= 0 and choisir.is_valid(): morceaux.append({"texte":"n° %d →" % (slot + 1), "action":func(): choisir.call(slot)})
			var raison := str(conseil.get("court", "")).get_slice(" · ", 1)
			if not raison.is_empty(): morceaux.append({"texte":"· " + raison, "couleur":Charte.IVOIRE_2})
		else:
			morceaux.append({"texte":str(conseil.get("court", conseil.get("texte", "")))})
		Kit.flux(app, cadre, 0, 20, texte_l, morceaux, 17, 22, 2, "TacticsStaffAdvice%dPart" % i)
	var cadre_gabi := Control.new()
	cadre_gabi.name = "TacticsGabi"
	cadre_gabi.clip_contents = true
	cadre_gabi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(cadre_gabi)
	D.place(cadre_gabi, Rect2(w - 22 - portrait, h - 160, portrait, 146))
	var visage := PORTRAIT.new() as TextureRect
	visage.name = "TacticsGabiFace"
	cadre_gabi.add_child(visage)
	visage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visage.set_context("tactique")
## Conseils du staff par place (pour marquer les postes contestés) : {slot: texte complet}.
static func avis(app: Control) -> Dictionary:
	var marques := {}
	var data: Variant = app.model.get("selection", {}).get("staffAdvice")
	if not data is Dictionary: return marques
	for conseil: Variant in data.get("conseils", []):
		if conseil is Dictionary: marques[int(conseil.get("slot", -1))] = str(conseil.get("texte", ""))
	return marques
