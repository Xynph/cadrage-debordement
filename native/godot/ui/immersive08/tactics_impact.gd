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

static func build(app: Control, page: Control, zone: Rect2, adversaire: String) -> Panel:
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
		Kit.texte(bloc, 22, y, "Projection du staff · se recalcule à chaque changement", Charte.IVOIRE_2, w - 44, 16)
		y += 14
		for i in DUELS.size():
			_duel(bloc, i, y + i * 41, w, DUELS[i], valeurs.get(DUELS[i][0], {}), app.accent)
		y += DUELS.size() * 41 + 20
	_lignes(app, bloc, y, w, valeurs)
	_gabi(app, bloc, w, zone.size.y)
	return bloc

static func _nombre(valeur: Variant) -> Variant:
	return float(valeur) if (valeur is int or valeur is float) and is_finite(float(valeur)) else null

static func _duel(bloc: Control, rang: int, y: float, w: float, duel: Array, domaine: Dictionary, accent: Color) -> void:
	var nous: Variant = _nombre(domaine.get("own"))
	var eux: Variant = _nombre(domaine.get("opponent"))
	var ligne := Control.new()
	ligne.name = "TacticsDuel_" + str(duel[0])
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(ligne)
	D.place(ligne, Rect2(22, y, w - 44, 41))
	if rang > 0: D.line(ligne, Vector2(0, 0), Vector2(w - 44, 0), Charte.PANNEAU_2)
	var barre := 100.0
	var gras := Kit.texte_gras()
	var a := D.text(ligne, 40, 27, G.n(roundi(nous)) if nous != null else "—", 18, Charte.IVOIRE, 700, 38, HORIZONTAL_ALIGNMENT_RIGHT, true)
	a.add_theme_font_override("font", gras)
	a.name = "TacticsDomainOwn"
	if nous != null: D.rect(ligne, Rect2(48 + barre * (1.0 - clampf(nous, 0, 100) / 100.0), 14, barre * clampf(nous, 0, 100) / 100.0, 13), Charte.club_trait(accent), 0)
	Kit.texte(ligne, 248, 27, str(duel[1]), Charte.IVOIRE, 190, 18, HORIZONTAL_ALIGNMENT_CENTER)
	if eux != null: D.rect(ligne, Rect2(350, 14, barre * clampf(eux, 0, 100) / 100.0, 13), Charte.IVOIRE_2, 0)
	var b := D.text(ligne, 458, 27, G.n(roundi(eux)) if eux != null else "—", 18, Charte.IVOIRE, 700, 40, HORIZONTAL_ALIGNMENT_LEFT, true)
	b.add_theme_font_override("font", gras)
	b.name = "TacticsDomainOpponent"
	if nous != null and eux != null:
		var ecart := roundi(nous) - roundi(eux)
		var texte := "▲ +%d" % ecart if ecart > 0 else ("▼ −%d" % -ecart if ecart < 0 else "= 0")
		var e := D.text(ligne, w - 44, 27, texte, 18, Charte.IVOIRE if ecart >= 0 else Charte.IVOIRE_2, 700, 70, HORIZONTAL_ALIGNMENT_RIGHT, true)
		e.add_theme_font_override("font", gras)
		e.name = "TacticsDomainGap"
	ligne.set_meta("libelle", "%s : %s contre %s" % [duel[1], a.text, b.text])

## Vigilance (joueurs de la feuille sous 80 % de condition), au près, au large, lien vers le dossier adverse.
static func _lignes(app: Control, bloc: Control, y: float, w: float, valeurs: Dictionary) -> void:
	var sous: Array[String] = []
	for slot in 23:
		var person := Selection.occupant(app.model, slot)
		var forme: Variant = person.get("condition")
		if (forme is int or forme is float) and float(forme) < 80: sous.append(PersonName.initial_and_surname(str(person.get("name", ""))))
	var vigilance := "Aucune alerte physique sur la feuille" if sous.is_empty() else "! %d joueur%s sous 80 %% : %s" % [sous.size(), "s" if sous.size() > 1 else "", ", ".join(sous)]
	var lignes: Array = [["Vigilance", vigilance, "TacticsVigilance", Charte.D if not sous.is_empty() else Charte.IVOIRE]]
	if not valeurs.is_empty():
		lignes.append(["Au près", _resume(valeurs, PRES), "TacticsClose", Charte.IVOIRE])
		lignes.append(["Au large", _resume(valeurs, LARGE), "TacticsWide", Charte.IVOIRE])
	for i in lignes.size():
		var entree: Array = lignes[i]
		var haut := y + i * 36
		Kit.etiquette(bloc, 22, haut + 22, str(entree[0]), 120)
		var texte := Kit.texte(bloc, 150, haut + 23, str(entree[1]), entree[3], w - 172)
		texte.name = str(entree[2])
		D.line(bloc, Vector2(22, haut + 34), Vector2(w - 22, haut + 34), Charte.PANNEAU_2)
	var lien := Kit.lien(bloc, Rect2(16, y + lignes.size() * 36 + 10, 0, 34), "Voir le dossier adverse →", func(): app.Immersive.open_preparation(app, 0), "TacticsOpponentFile")
	lien.tooltip_text = "Dossier de préparation : forces et habitudes de l’adversaire"

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

## Bulle de Gabi : l'avis du staff sur la feuille (au plus trois conseils, texte complet en infobulle).
static func _gabi(app: Control, bloc: Control, w: float, h: float) -> void:
	var bulle := D.rect(bloc, Rect2(22, h - 176, w - 44 - 150, 150), Charte.PANNEAU_2, 0)
	bulle.name = "TacticsStaffAdvice"
	bulle.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.marqueur(bulle, Rect2(6, 12, 4, 126), Charte.club_trait(app.accent))
	Kit.etiquette(bulle, 22, 28, "Gabi · avis du staff", 300)
	var data: Variant = app.model.get("selection", {}).get("staffAdvice")
	var conseils: Array = data.get("conseils", []) if data is Dictionary else []
	if data is Dictionary and conseils.is_empty():
		Kit.texte(bulle, 22, 58, "Ton staff valide ta feuille.", Charte.IVOIRE, w - 44 - 150 - 34).name = "TacticsStaffAdviceAgree"
	elif conseils.is_empty():
		var texte := "Clique un poste pour voir qui peut le tenir."
		var erreurs: Array = app.model.get("selection", {}).get("errors", [])
		if not erreurs.is_empty(): texte = "Complète d’abord la feuille : " + str(erreurs[0])
		var label := Kit.texte(bulle, 22, 58, texte, Charte.IVOIRE, w - 44 - 150 - 34)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 4
		label.size.y = C.px(100)
	for i in mini(conseils.size(), 3):
		var conseil: Dictionary = conseils[i]
		var label := Kit.texte(bulle, 22, 58 + i * 30, "• " + str(conseil.get("court", conseil.get("texte", ""))), Charte.IVOIRE, w - 44 - 150 - 34, 17)
		label.name = "TacticsStaffAdvice%d" % i
		label.tooltip_text = str(conseil.get("texte", ""))
		label.mouse_filter = Control.MOUSE_FILTER_PASS
	var cadre := Control.new()
	cadre.name = "TacticsGabi"
	cadre.clip_contents = true
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloc.add_child(cadre)
	D.place(cadre, Rect2(w - 22 - 150, h - 196, 150, 170))
	var visage := PORTRAIT.new() as TextureRect
	visage.name = "TacticsGabiFace"
	cadre.add_child(visage)
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
