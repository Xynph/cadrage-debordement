extends RefCounted
## Lecture commune de la fiche joueur complète (player_canvas.gd) et de la mini-fiche au survol (mini_fiche.gd) :
## retrouver un joueur projeté, sa liste d'origine, sa disponibilité, et dessiner la grille des 36 attributs au
## barème de la charte. Aucune donnée de carrière n'est écrite ici ; une donnée absente est omise, jamais inventée.
## Exemple : `FicheCommune.grille_attributs(carte, Vector2(24,64), Vector2(1372,340), joueur, true, "PlayerDetailedAttribute_")`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Charte = preload("res://ui/charte.gd")
const PlayerAttributes = preload("res://ui/player_attributes.gd")
const Knowledge = preload("res://ui/player_knowledge_text.gd")
const NotesMatch = preload("res://ui/notes_match.gd")

## Sources d'une fiche : effectif professionnel, marché des joueurs, Espoirs du centre de formation.
const SOURCES := ["squad", "market", "academy"]
## Route de l'écran d'origine de chaque source (retour, fil d'Ariane).
const ROUTES := {"squad":"Effectif", "market":"Recrutement", "academy":"Formation"}
const RETOURS := {"squad":"Retour à l’effectif", "market":"Retour au recrutement", "academy":"Retour à la formation"}

static func _personnes(app: Control, source: String) -> Array:
	match source:
		"squad": return app.model.get("squad", [])
		"market": return app.model.get("market", [])
		"academy": return app.model.get("decisions", {}).get("development", {}).get("academy", [])
	return []

## Joueur projeté et sa source ; `source` vide : effectif d'abord, puis marché, puis Espoirs.
static func trouver(app: Control, id: String, source: String = "") -> Dictionary:
	if id.is_empty(): return {}
	if source == "adverse": return adverse(app, id)
	for candidate: String in ([source] if source in SOURCES else SOURCES):
		for person: Variant in _personnes(app, candidate):
			if person is Dictionary and str(person.get("id", "")) == id: return {"joueur":person, "source":candidate}
	return {}

## Joueur d'un club adverse lu dans la fiche du club déjà chargée (commande de lecture seule « club_sheet ») : seulement
## ce que le jeu en connaît (poste, âge, niveau selon le brouillard, club) ; les attributs restent « — ».
static func adverse(app: Control, id: String) -> Dictionary:
	var cache: Variant = app.get_meta("club_sheet_cache", {})
	if not (cache is Dictionary and cache.get("sheets") is Dictionary): return {}
	for fiche: Variant in cache.sheets.values():
		if not fiche is Dictionary: continue
		for person: Variant in fiche.get("squad", []):
			if not person is Dictionary or str(person.get("id", "")) != id: continue
			var joueur: Dictionary = person.duplicate()
			joueur.club = str(fiche.get("name", ""))
			joueur.playerFacts = {"nationality":person.get("nationality"), "flagCode":person.get("flagCode"), "onInternationalDuty":person.get("onInternationalDuty", false), "seniorNationName":person.get("seniorNationName")}
			return {"joueur":joueur, "source":"adverse"}
	return {}

## Contexte du club : les joueurs de l'effectif et les Espoirs sont connus en détail ; une piste du marché suit le
## brouillard de connaissance (ui/player_knowledge_text.gd).
static func notre_joueur(source: String) -> bool:
	return source in ["squad", "academy"]

## Identifiants de la liste d'origine, dans l'ordre affiché par l'écran (précédent / suivant de la fiche).
static func liste(app: Control, source: String) -> Array[String]:
	var ids: Array[String] = []
	if source == "squad":
		var copies: Array = []
		for player: Variant in app.model.get("squad", []):
			if not player is Dictionary: continue
			var copie: Dictionary = player.duplicate()
			copie.matchNotes = NotesMatch.joueur(app.model, str(player.get("id", "")))
			copies.append(copie)
		var lecture: Dictionary = app.management_ui.get("roster", {}) if app.management_ui.get("roster") is Dictionary else {}
		# Chargé à l'usage : squad_canvas.gd charge lui-même la mini-fiche (pas de préchargement circulaire).
		for player: Dictionary in load("res://ui/immersive08/squad_canvas.gd").ordered_players(copies, lecture, int(app.model.get("meta", {}).get("season", 1))):
			ids.append(str(player.get("id", "")))
		return ids
	for player: Variant in _personnes(app, source):
		if player is Dictionary: ids.append(str(player.get("id", "")))
	return ids

## « tri : poste » (effectif) ou le nom de la liste d'origine.
static func libelle_liste(app: Control, source: String) -> String:
	if source == "squad":
		var lecture: Variant = app.management_ui.get("roster")
		var tri := str(lecture.get("sort", "Poste")) if lecture is Dictionary else "Poste"
		return "tri : " + tri.to_lower()
	return "pistes du marché" if source == "market" else "Espoirs du centre"

## Statut de feuille lisible : « titulaire n° 2 », « remplaçant n° 18 », « hors groupe » ; vide hors effectif.
static func statut_feuille(player: Dictionary, source: String) -> String:
	if source == "adverse": return str(player.get("club", ""))
	if source == "academy": return "Espoir · " + ("U18" if int(player.get("age", 99)) <= 18 else "U21")
	if source != "squad": return ""
	var numero: Variant = player.get("shirtNumber")
	if not (numero is int or numero is float): return "hors groupe"
	return ("titulaire n° %d" if int(numero) <= 15 else "remplaçant n° %d") % int(numero)

## Disponibilité : {etat, texte, couleur}. Blessé, suspendu, en sélection ou en reprise remplacent la forme ;
## le retour n'est donné que s'il est connu (semaines restantes), jamais une date inventée.
static func disponibilite(app: Control, player: Dictionary, source: String) -> Dictionary:
	var injury := float(player.get("injury", 0)) if player.get("injury") is int or player.get("injury") is float else 0.0
	if injury > 0:
		var label := preload("res://ui/club_mail.gd").injury_label(app.model, player)
		var semaines := ceili(injury)
		return {"etat":"blesse", "texte":"%s · retour dans %d sem." % [label, semaines], "couleur":Charte.D}
	var suspension: Variant = player.get("suspension")
	if (suspension is int or suspension is float) and float(suspension) > 0:
		return {"etat":"suspendu", "texte":"Suspendu · %d match%s" % [int(suspension), "s" if int(suspension) > 1 else ""], "couleur":Charte.D}
	var facts: Variant = player.get("playerFacts")
	if facts is Dictionary and facts.get("onInternationalDuty", false):
		var nation := str(facts.get("seniorNationName", "")) if facts.get("seniorNationName") is String else ""
		return {"etat":"selection", "texte":"En sélection" + (" · " + nation if not nation.is_empty() else ""), "couleur":Charte.N}
	if source == "squad" and P.player_in_recovery(app.model, str(player.get("id", ""))):
		return {"etat":"reprise", "texte":"En reprise", "couleur":Charte.N}
	return {"etat":"apte", "texte":"apte", "couleur":Charte.V}

## Condition connue (0-100) ou null.
static func condition(player: Dictionary) -> Variant:
	var value: Variant = player.get("condition")
	return clampf(float(value), 0, 100) if value is int or value is float else null

## « 2027 · fin de saison » quand le contrat s'achève cette saison ; « — » inconnu.
static func echeance(app: Control, player: Dictionary) -> String:
	var fin: Variant = player.get("contractEnd")
	var texte := G.contract_year(fin)
	if texte != "—" and int(fin) <= int(app.model.get("meta", {}).get("season", 1)): texte += " ⧗ fin de saison"
	return texte

## Valeurs des 36 attributs si elles sont connues, sinon {} (afficher « — »).
static func valeurs(player: Dictionary, source: String) -> Dictionary:
	return PlayerAttributes.detail(player, notre_joueur(source))

static func moyenne_famille(values: Dictionary, entries: Array) -> Variant:
	if values.is_empty(): return null
	var total := 0.0
	var count := 0
	for pair: Array in entries:
		var value: Variant = values.get(pair[0])
		if value is int or value is float:
			total += float(value)
			count += 1
	return roundi(total / count) if count > 0 else null

## Trois meilleurs et trois plus faibles attributs : [[clé, libellé, valeur], …] ; vides si inconnus.
static func points(values: Dictionary) -> Array:
	var all: Array = []
	for group: Array in PlayerAttributes.GROUPS:
		for pair: Array in group[1]:
			var value: Variant = values.get(pair[0])
			if value is int or value is float: all.append([pair[0], pair[1], value])
	if all.is_empty(): return [[], []]
	all.sort_custom(func(a: Array, b: Array): return float(a[2]) > float(b[2]) or (float(a[2]) == float(b[2]) and str(a[0]) < str(b[0])))
	var faibles := all.slice(maxi(3, all.size() - 3))
	faibles.reverse()
	return [all.slice(0, 3), faibles]

## Grille 4 familles × 9 attributs, en unités du gabarit (2560 × 1440) relatives à `parent`.
## Chaque valeur est un Label nommé `prefixe + clé` : chiffre coloré au barème, « — » en ivoire-3 si inconnu.
## `tailles` : {titre, libelle, valeur, pas} (unités).
static func grille_attributs(parent: Control, origine: Vector2, dimension: Vector2, values: Dictionary, prefixe: String, tailles: Dictionary = {}) -> void:
	var titre := int(tailles.get("titre", 20))
	var libelle := int(tailles.get("libelle", 21))
	var valeur := int(tailles.get("valeur", 25))
	var pas := float(tailles.get("pas", 33))
	var ecart := float(tailles.get("ecart", 28))
	var colonne := (dimension.x - ecart * 3.0) / 4.0
	for i in PlayerAttributes.GROUPS.size():
		var group: Array = PlayerAttributes.GROUPS[i]
		var x := origine.x + i * (colonne + ecart)
		var mot_moy := bool(tailles.get("mot_moyenne", true))
		var entete := D.text(parent, x, origine.y + titre, str(group[0]).to_upper(), titre, Charte.IVOIRE, 700, colonne - (100.0 if mot_moy else 40.0))
		entete.name = prefixe.trim_suffix("_") + "Famille" + str(i)
		entete.tooltip_text = str(group[0])
		var moyenne: Variant = moyenne_famille(values, group[1])
		if moyenne != null:
			if mot_moy: D.text(parent, x + colonne - 38, origine.y + titre, "moy.", titre - 3, Charte.IVOIRE_2, 500, 56, HORIZONTAL_ALIGNMENT_RIGHT)
			var chiffre := D.text(parent, x + colonne, origine.y + titre, G.n(moyenne), titre + 2, Charte.couleur_attribut(moyenne), 700, 34, HORIZONTAL_ALIGNMENT_RIGHT)
			chiffre.name = prefixe.trim_suffix("_") + "Moyenne" + str(i)
		D.line(parent, Vector2(x, origine.y + titre + 10), Vector2(x + colonne, origine.y + titre + 10), Color(Charte.FILET, .9))
		var entries: Array = group[1]
		for j in entries.size():
			var pair: Array = entries[j]
			var y := origine.y + titre + 10 + pas * (j + 1) - pas * .28
			D.text(parent, x, y, pair[1], libelle, Charte.IVOIRE, 500, colonne - 46, HORIZONTAL_ALIGNMENT_LEFT, bool(tailles.get("corps", true)))
			var value: Variant = values.get(pair[0])
			var number := D.text(parent, x + colonne, y, PlayerAttributes.caption(value), valeur, Charte.couleur_attribut(value), 700, 46, HORIZONTAL_ALIGNMENT_RIGHT)
			number.name = prefixe + str(pair[0])
			number.tooltip_text = "%s · %s / 100" % [pair[1], PlayerAttributes.caption(value)] if value != null else "%s · inconnu" % pair[1]

## Légende du barème : six libellés colorés, alignés à droite sur `droite` (unités). Renvoie la largeur occupée.
static func legende(parent: Control, droite: float, ligne: float, taille: int = 18) -> Control:
	var groupe := Control.new()
	groupe.name = "LegendeBaremeAttributs"
	groupe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(groupe)
	var police: Font = C.font(700)
	var pixels := maxi(12, C.px(taille))
	var x := 0.0
	var largeurs: Array[float] = []
	for palier: Array in Charte.BAREME_ATTRIBUTS:
		largeurs.append(police.get_string_size(str(palier[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x / C.density + 4)
	var total := 0.0
	for largeur: float in largeurs: total += largeur + 16
	for k in Charte.BAREME_ATTRIBUTS.size():
		var palier: Array = Charte.BAREME_ATTRIBUTS[k]
		var mot := D.text(groupe, x, taille, palier[2], taille, palier[1], 700, largeurs[k])
		mot.name = "Palier" + str(k)
		x += largeurs[k] + 16
	D.place(groupe, Rect2(droite - total, ligne - taille, total, taille + 8))
	groupe.tooltip_text = "Barème des attributs, notes de 1 à 100"
	return groupe
