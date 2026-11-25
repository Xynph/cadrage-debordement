extends RefCounted
## Discussion avec un joueur (revue FM27, idée 23, choix de Léo du 23/11/2026) : petite fenêtre ouverte depuis
## Vestiaire › Entretiens et duos (carte « Discuter »). Fenêtre commune fenetre_discussion.gd : à gauche ses données
## (portrait, attitude, hiérarchie Relais / Cadre / Groupe / Jeune, caractère, forme, satisfaction, confiance, temps de
## jeu promis), à droite l'échelle d'attitude, le fil et trois phrases ; un clic sur une phrase la dit tout de suite.
## Données : moteur relationships.cjs + discussion-joueur.cjs (players[].discussion : situation, hiérarchie, attitude,
## phrases du moment, fil des derniers échanges ; l'effet réel dépend du caractère), squad[].tempsJeu (role-contrat.cjs),
## notes de match (5 dernières).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const FenetreDiscussion = preload("res://ui/fenetre_discussion.gd")
const V = preload("res://ui/relationships_visuals.gd")
const G = preload("res://ui/carnet_skin.gd")
const NotesMatch = preload("res://ui/notes_match.gd")
const Tableau = preload("res://ui/contextual/match_tableau_widgets.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Role = preload("res://ui/role_contrat.gd")
const TempsJeu = preload("res://ui/immersive08/fiche_temps_jeu.gd")

const NOM := "DiscussionFenetre"
const CLE := "discussion"
## Paliers d'attitude (satisfaction, seuils du moteur 30 / 45 / 55 / 65 / 80) : mot, couleur, icône.
const ATTITUDES := [["Fermé", Pastilles.ROUGE, "warning"], ["Mécontent", Pastilles.ORANGE, "warning"], ["Inexpressif", Charte.IVOIRE_2, "info"],
	["Neutre", Pastilles.BLEU, "people"], ["Content", Pastilles.VERT, "check"], ["Enthousiaste", Pastilles.TURQUOISE, "star"]]
const SEUILS := [30, 45, 55, 65, 80]
## Hiérarchie du vestiaire (moteur) : mot, couleur, icône.
const HIERARCHIES := {"relais": ["Relais", Pastilles.VIOLET, "star"], "cadre": ["Cadre", Pastilles.BLEU, "shield"],
	"groupe": ["Groupe", Charte.IVOIRE_2, "people"], "jeune": ["Jeune", Pastilles.TURQUOISE, "people"]}
## Situation qui change les phrases proposées (normal et mécontent : l'attitude suffit).
const SITUATIONS := {"blesse": ["Blessé", Pastilles.ROUGE, "warning"], "temps_jeu": ["Temps de jeu", Pastilles.ORANGE, "clock"],
	"peu_utilise": ["Peu utilisé", Pastilles.ORANGE, "clock"], "en_forme": ["En forme", Pastilles.VERT, "rating"]}
## Nature d'une phrase → icône et couleur.
const NATURES := {"ecoute": ["heart", Pastilles.BLEU], "soutien": ["shield", Pastilles.VERT], "eloge": ["star", Pastilles.TURQUOISE],
	"critique": ["flag", Pastilles.ROUGE], "exigence": ["info", Pastilles.ORANGE], "collectif": ["people", Pastilles.VIOLET]}

static func palier(score: Variant) -> int:
	if not (score is int or score is float): return 2
	var n := 0
	for s: int in SEUILS:
		if float(score) >= s: n += 1
	return n

static func style(nature: String) -> Array:
	return NATURES.get(nature, ["mail", Charte.IVOIRE_2])

## Carte « Discuter » de la colonne du joueur (remplace les trois lignes d'entretien).
static func bouton(app: Control, p: Dictionary) -> Control:
	var disc: Dictionary = p.get("discussion", {}) if p.get("discussion") is Dictionary else {}
	var att: Array = ATTITUDES[clampi(int(disc.get("attitude", palier(p.get("score")))), 0, ATTITUDES.size() - 1)]
	var ligne := C.h(12)
	var lisere := ColorRect.new()
	lisere.color = Pastilles.BLEU
	lisere.custom_minimum_size = Vector2(C.px(5), C.px(40))
	ligne.add_child(lisere)
	var icone := C.icon("people", 28, Pastilles.BLEU)
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(icone)
	var mot := C.label("Discuter", 22, Charte.IVOIRE, true, 700)
	mot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(mot)
	var etat := Pastilles.pastille(str(att[0]), att[1], str(att[2]), "Attitude", 16)
	etat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(etat)
	# Discussion de la semaine : « Vu » une fois conclue, « 1/3 » ou « 2/3 » en cours (reprise au même tour).
	var vu: Control = null
	if bool(disc.get("faite", false)) or (disc.is_empty() and not p.get("conversationAvailable", false)): vu = Pastilles.pastille("Vu", Charte.IVOIRE_2, "clock", "Discussion de la semaine faite", 16, "DiscussionVuSemaine")
	elif bool(disc.get("enCours", false)): vu = Pastilles.pastille("%d/%d" % [int(disc.get("tour", 0)), int(disc.get("tours", 3))], Pastilles.ORANGE, "clock", "Discussion en cours", 16, "DiscussionEnCours")
	if vu != null:
		vu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(vu)
	var fleche := C.label("›", 26, Charte.IVOIRE_2, true, 700)
	fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(fleche)
	var id := str(p.get("id", ""))
	return V.carte(ligne, func(): ouvrir(app, id), "DiscussionOuvrir", "Discuter", Pastilles.BLEU)

## Rouvre la fenêtre après un nouveau rendu du Vestiaire (réponse du moteur).
static func reprendre(app: Control, canvas: Control) -> void:
	var etat: Variant = app.management_ui.get(CLE)
	if etat is Dictionary and not str(etat.get("id", "")).is_empty(): _dessiner(app, canvas, str(etat.id))

static func _toile(app: Control) -> Control:
	var canvas := app.find_child("ImmersiveLockerRoom", true, false) as Control
	return canvas if canvas != null else app

static func ouvrir(app: Control, id: String) -> void:
	var etat: Variant = app.management_ui.get(CLE)
	if not (etat is Dictionary and str(etat.get("id", "")) == id): app.management_ui[CLE] = {"id": id}
	_dessiner(app, _toile(app), id)

static func _oublier(app: Control) -> void:
	app.management_ui.erase(CLE)

## Données du joueur pour la fenêtre ; {} si le joueur n'est plus suivi.
static func donnees(app: Control, id: String) -> Dictionary:
	var rel: Dictionary = app.model.get("clubLife", {}).get("relationships", {})
	var p: Dictionary = {}
	for x: Dictionary in rel.get("players", []):
		if str(x.get("id")) == id: p = x
	if p.is_empty(): return {}
	var identite: Dictionary = {"id": id}
	for s: Dictionary in app.model.get("squad", []):
		if str(s.get("id")) == id: identite = s
	var personnalite: Variant = p.get("personality")
	var disc: Dictionary = p.get("discussion", {}) if p.get("discussion") is Dictionary else {}
	var etat: Dictionary = app.management_ui.get(CLE, {}) if app.management_ui.get(CLE) is Dictionary else {}
	# Phrase envoyée, réponse du moteur reçue (le tour a avancé) : elle quitte l'attente.
	if etat.get("envoi") is Dictionary and int(disc.get("tour", 0)) > int(etat.envoi.get("tour", -1)): etat.erase("envoi")
	return {"id": id, "p": p, "identite": identite, "nom": str(identite.get("name", "Joueur")), "poste": str(p.get("pos", "")),
		"score": p.get("score"), "confiance": p.get("trust"), "condition": int(p.get("condition", 0)), "minutes": p.get("minutes"),
		"trait": str(personnalite.get("trait", "")) if personnalite is Dictionary else "", "disc": disc,
		"forme": NotesMatch.forme(NotesMatch.joueur(app.model, id)), "tempsJeu": identite.get("tempsJeu") if identite.get("tempsJeu") is Dictionary else {},
		"libre": not etat.has("envoi") and not (disc.get("phrases", []) as Array).is_empty(),
		"contexte": rel.get("context", {}), "etat": etat}

## Nos mots : la phrase s'affiche aussitôt dans le fil, le moteur répond, la fenêtre revient au nouveau rendu.
static func _dire(app: Control, d: Dictionary, phrase: Dictionary) -> void:
	var envoi: Dictionary = phrase.duplicate(true)
	envoi["tour"] = int(d.disc.get("tour", 0))
	app.management_ui[CLE] = {"id": d.id, "envoi": envoi}
	ouvrir(app, str(d.id))
	app._command("relationship_conversation", {"context": d.contexte, "playerId": d.id, "choice": str(phrase.get("choice", "ecouter")), "phrase": str(phrase.get("id", ""))})

static func _fiche(app: Control, id: String) -> Callable:
	var nav: Variant = app.get("navigation_controller")
	var cible := {"kind": "player", "id": id}
	if not is_instance_valid(nav) or not nav.has_method("entity_available") or not nav.entity_available(cible): return Callable()
	return func():
		Fenetre.fermer(app, NOM)
		_oublier(app)
		nav.open_entity(cible)

static func _attitude(index: int, taille: int = 20, id: String = "") -> Control:
	var a: Array = ATTITUDES[clampi(index, 0, ATTITUDES.size() - 1)]
	return Pastilles.pastille(str(a[0]), a[1], str(a[2]), "Attitude : " + str(a[0]), taille, id)

static func _dessiner(app: Control, canvas: Control, id: String) -> void:
	var d := donnees(app, id)
	if d.is_empty():
		_oublier(app)
		return
	var disc: Dictionary = d.disc
	var envoi: Dictionary = d.etat.get("envoi", {}) if d.etat.get("envoi") is Dictionary else {}
	var choix: Array = []
	for ph: Dictionary in disc.get("phrases", []):
		var st := style(str(ph.get("nature", "")))
		var phrase := ph
		choix.append({"id": "DiscussionPhrase_" + str(ph.get("id", "")), "texte": str(ph.get("texte", "")), "icone": st[0], "couleur": st[1],
			"action": func(): _dire(app, d, phrase), "actif": d.libre, "choisi": str(envoi.get("id", "")) == str(ph.get("id", ""))})
	FenetreDiscussion.ouvrir(canvas, {"nom": NOM, "titre": "Discussion", "icone": "people", "fermeture": func(): _oublier(app),
		"gauche": func(f: Control, zone: Rect2): _gauche(app, f, zone, d),
		"echelle": {"paliers": ATTITUDES, "avant": int(disc.get("attitudeAvant", palier(d.score))), "apres": int(disc.get("attitude", palier(d.score)))},
		"visage": func() -> Control: return _visage(d, 52),
		"fil": _fil(d, envoi), "choix": choix})

## ---- Fil : la discussion de la semaine tour par tour (nos mots, sa réponse, sa réaction), conclusion -----------------

static func _fil(d: Dictionary, envoi: Dictionary) -> Array:
	var disc: Dictionary = d.disc
	var fil: Array = []
	var derniere: Dictionary = disc.get("fil", {}) if disc.get("fil") is Dictionary else {}
	var courante := bool(derniere.get("courante", false))
	# Discussion d'une semaine passée : un repère (date et effet) avant la nouvelle.
	if not derniere.is_empty() and not courante:
		var ligne := C.h(10)
		ligne.add_child(Pastilles.pastille("%s J%d" % [G.season_label(derniere.get("season")), int(derniere.get("round", 0)) + 1], Charte.IVOIRE_3, "calendar", "Dernière discussion", 15, "DiscussionDateAvant"))
		ligne.add_child(_effet(derniere, "DiscussionEffetAvant", 15))
		fil.append({"qui": "repere", "id": "DiscussionAvant", "controle": ligne})
	fil.append({"qui": "lui", "id": "DiscussionBulleAccueil", "texte": str(disc.get("accueil", "Oui, coach ?")), "couleur": Pastilles.BLEU})
	var tours: Array = derniere.get("tours", []) if courante else []
	for i in tours.size():
		var t: Dictionary = tours[i]
		fil.append({"qui": "moi", "id": "DiscussionBulleCoach%d" % i, "texte": str(t.get("texte", "")), "couleur": style(str(t.get("nature", "")))[1]})
		fil.append({"qui": "lui", "id": "DiscussionBulleJoueur%d" % i, "texte": str(t.get("reponse", "")), "couleur": Pastilles.BLEU, "effet": _reaction(int(t.get("reaction", 0)), "DiscussionReaction%d" % i)})
	if not envoi.is_empty():
		fil.append({"qui": "moi", "id": "DiscussionBulleCoachEnvoi", "texte": str(envoi.get("texte", "")), "couleur": style(str(envoi.get("nature", "")))[1]})
	elif bool(disc.get("faite", false)):
		# Conclusion : effet total sur la satisfaction, discussion de la semaine faite.
		var fin := C.h(10)
		if courante: fin.add_child(_effet(derniere, "DiscussionEffetTotal", 17))
		fin.add_child(Pastilles.pastille("Vu cette semaine", Charte.IVOIRE_2, "clock", "Une discussion par joueur et par semaine", 16, "DiscussionDejaVu"))
		fil.append({"qui": "repere", "id": "DiscussionFin", "controle": fin})
	return fil

## Réaction à une phrase : ▲ bien reçue, ● sans effet, ▼ mal reçue (couleur jamais seule : forme et mot).
static func _reaction(r: int, id: String) -> Control:
	if r > 0: return Pastilles.pastille("▲ Bien reçu", Pastilles.VERT, "", "Sa réaction", 15, id)
	if r < 0: return Pastilles.pastille("▼ Mal reçu", Pastilles.ROUGE, "", "Sa réaction", 15, id)
	return Pastilles.pastille("● Sans effet", Charte.IVOIRE_2, "", "Sa réaction", 15, id)

## Effet réel de la discussion : ▲ / ▼ satisfaction avant → après.
static func _effet(e: Dictionary, id: String, taille: int = 16) -> Control:
	var effet := int(e.get("effet", 0))
	var couleur: Color = Pastilles.VERT if effet > 0 else (Pastilles.ROUGE if effet < 0 else Charte.IVOIRE_2)
	var signe := "▲ +%d" % effet if effet > 0 else ("▼ −%d" % absi(effet) if effet < 0 else "= 0")
	var texte := "%s satisf." % signe
	if (e.get("avant") is int or e.get("avant") is float) and (e.get("apres") is int or e.get("apres") is float): texte += " · %d → %d" % [int(e.avant), int(e.apres)]
	return Pastilles.pastille(texte, couleur, "heart", "Satisfaction", taille, id)

## ---- Données du joueur (gauche) ----------------------------------------------------------------------------------

static func _gauche(app: Control, f: Control, zone: Rect2, d: Dictionary) -> void:
	var disc: Dictionary = d.disc
	var x0 := zone.position.x + 20
	var fiche := _fiche(app, str(d.id))
	_portrait(app, f, d, Rect2(x0, zone.position.y + 20, 150, 150))
	var xn := x0 + 172
	_nom(app, f, d, xn, zone.position.y + 66, 44, zone.end.x - xn - 20)
	var x := xn
	var h: Array = HIERARCHIES.get(str(disc.get("hierarchie", "groupe")), HIERARCHIES.groupe)
	x += Pastilles.poser(f, Pastilles.pastille(str(h[0]), h[1], str(h[2]), "Hiérarchie du vestiaire", 18, "DiscussionHierarchie", fiche), x, zone.position.y + 88) + 10
	if not str(d.poste).is_empty(): x += Pastilles.poser(f, Pastilles.pastille(str(d.poste), Charte.IVOIRE_2, "people", "Poste", 18, "DiscussionPoste", fiche), x, zone.position.y + 88) + 10
	if not str(d.trait).is_empty(): Pastilles.poser(f, Pastilles.pastille(str(d.trait), Pastilles.VIOLET, "heart", "Caractère", 18, "DiscussionTrait", fiche), x, zone.position.y + 88)
	x = xn
	x += Pastilles.poser(f, _attitude(int(disc.get("attitude", palier(d.score))), 22, "DiscussionAttitude"), x, zone.position.y + 130) + 10
	var sit: Variant = SITUATIONS.get(str(disc.get("situation", "")))
	if sit is Array: Pastilles.poser(f, Pastilles.pastille(str(sit[0]), sit[1], str(sit[2]), "Situation", 20, "DiscussionSituation", fiche), x, zone.position.y + 132)
	# Forme : 5 dernières notes de match.
	var y := zone.position.y + 214
	_section(f, x0, y, "Forme · 5 derniers matchs", "rating", Charte.IVOIRE_2)
	_courbe(f, Rect2(x0, y + 14, zone.size.x - 40, 180), d.forme)
	# Lui et le coach : satisfaction, confiance, condition, minutes.
	y += 244
	_section(f, x0, y, "Lui et le coach", "heart", Pastilles.BLEU)
	var rangee := C.h(18)
	rangee.name = "DiscussionJauges"
	var score := float(d.score) if (d.score is int or d.score is float) else 0.0
	rangee.add_child(V.anneau(score, "Satisf.", "heart", V.teinte(score), "DiscussionAnneauSatisfaction", fiche))
	rangee.add_child(V.anneau(float(d.confiance) if (d.confiance is int or d.confiance is float) else 0.0, "Confiance", "shield", Charte.CONFIANCE, "DiscussionAnneauConfiance", fiche))
	var tuiles := C.v(10)
	for t: Control in [Pastilles.tuile("%d %%" % int(d.condition), "condition", Pastilles.VERT if d.condition >= 80 else (Pastilles.ORANGE if d.condition >= 50 else Pastilles.ROUGE), Charte.PANNEAU_3, 30, "DiscussionCondition", false, fiche),
			Pastilles.tuile(str(int(d.minutes)) if (d.minutes is int or d.minutes is float) else "—", "minutes", Pastilles.TURQUOISE, Charte.PANNEAU_3, 30, "DiscussionMinutes", false, fiche)]:
		t.custom_minimum_size.x = C.px(170)
		tuiles.add_child(t)
	rangee.add_child(tuiles)
	Pastilles.poser(f, rangee, x0 + 8, y + 16)
	# Temps de jeu promis au contrat : rôle, humeur, minutes des 10 derniers matchs.
	y += 224
	_section(f, x0, y, "Temps de jeu promis", "clock", Pastilles.ORANGE)
	_temps_jeu(f, Rect2(x0, y + 14, zone.size.x - 40, zone.end.y - y - 30), d.tempsJeu, fiche)

static func _section(parent: Control, x: float, base: float, texte: String, icone: String, couleur: Color) -> void:
	var image := C.icon(icone, 22, couleur)
	parent.add_child(image)
	D.place(image, Rect2(x, base - 20, 22, 22))
	D.text(parent, x + 32, base, texte.to_upper(), 20, Charte.IVOIRE_2, 700, 480)

static func _portrait(app: Control, parent: Control, d: Dictionary, zone: Rect2) -> void:
	var fond := D.rect(parent, zone, Charte.PANNEAU_3, Charte.RAYON_CARTE)
	fond.clip_contents = true
	var visage := G.portrait(int(d.identite.get("portraitIndex", posmod(str(d.id).hash(), 32))), C.px(zone.size.x), d.identite)
	visage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(visage)
	visage.position = Vector2.ZERO
	visage.size = zone.size * C.density
	var action := _fiche(app, str(d.id))
	if not action.is_valid(): return
	var bouton := Button.new()
	bouton.name = "DiscussionPortrait"
	bouton.flat = true
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.tooltip_text = str(d.nom)
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	D.place(bouton, zone)
	CarteSurvol.lier(app, bouton, str(d.id), "squad")

static func _nom(app: Control, parent: Control, d: Dictionary, x: float, base: float, taille: int, largeur: float) -> void:
	var nom := D.text(parent, x, base, str(d.nom).to_upper(), taille, Charte.IVOIRE, 700, largeur)
	nom.add_theme_font_override("font", Charte.TITRE_FICHE)
	nom.clip_text = true
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var action := _fiche(app, str(d.id))
	if not action.is_valid(): return
	var bouton := Button.new()
	bouton.name = "DiscussionNom"
	bouton.flat = true
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	bouton.position = nom.position
	bouton.size = Vector2(minf(nom.size.x, Charte.TITRE_FICHE.get_string_size(nom.text, HORIZONTAL_ALIGNMENT_LEFT, -1, C.px(taille)).x), nom.size.y)
	CarteSurvol.lier_info(app, bouton, str(d.id), "squad")

static func _visage(d: Dictionary, cote: float) -> Control:
	var fond := PanelContainer.new()
	fond.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, int(cote * .5), 0))
	fond.custom_minimum_size = Vector2(C.px(cote), C.px(cote))
	fond.clip_contents = true
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var visage := G.portrait(int(d.identite.get("portraitIndex", posmod(str(d.id).hash(), 32))), C.px(cote), d.identite)
	visage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(visage)
	return fond

## Courbe de forme : les 5 dernières notes de match, points à la couleur de la note, chiffre au-dessus.
class Courbe extends Control:
	var notes: Array = []
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		var marge := Vector2(C.px(56), C.px(30))
		var l := size.x - marge.x * 2.0
		var h := size.y - marge.y * 2.0
		for g: float in [5.0, 6.0, 7.0, 8.0]:
			var y := marge.y + h * (1.0 - (g - 4.5) / 4.0)
			draw_line(Vector2(marge.x, y), Vector2(marge.x + l, y), Charte.FILET, 1.0)
			draw_string(C.BOLD, Vector2(0, y + C.px(6)), str(int(g)), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(16)), Charte.IVOIRE_3)
		if notes.is_empty():
			draw_string(C.BOLD, Vector2(marge.x, size.y * .5), "—", HORIZONTAL_ALIGNMENT_CENTER, l, maxi(12, C.px(30)), Charte.IVOIRE_3)
			return
		var points := PackedVector2Array()
		var depart := 5 - notes.size()
		for i in notes.size():
			var n := clampf(float(notes[i]), 4.5, 8.5)
			points.append(Vector2(marge.x + l * float(depart + i) / 4.0, marge.y + h * (1.0 - (n - 4.5) / 4.0)))
		if points.size() > 1: draw_polyline(points, Charte.IVOIRE_2, maxf(2.0, C.px(3)), true)
		for i in points.size():
			var teinte: Color = Tableau.Teintes.note(float(notes[i]))
			draw_circle(points[i], maxf(4.0, C.px(9)), teinte)
			var t := ("%.1f" % float(notes[i])).replace(".", ",")
			var corps := maxi(12, C.px(20))
			var lt := C.BOLD.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
			draw_string(C.BOLD, points[i] + Vector2(-lt * .5, -C.px(16)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, teinte)

static func _courbe(parent: Control, zone: Rect2, notes: Array) -> Control:
	var courbe := Courbe.new()
	courbe.name = "DiscussionCourbeForme"
	courbe.notes = notes.slice(-5)
	var textes: Array[String] = []
	for n: Variant in courbe.notes: textes.append(NotesMatch.texte_note(n))
	courbe.tooltip_text = "Forme : " + (" · ".join(textes) if not textes.is_empty() else "aucun match noté")
	parent.add_child(courbe)
	D.place(courbe, zone)
	return courbe

## Minutes des 10 derniers matchs en barres (vert = exigence tenue, rouge = manquée, gris = absent ou sans exigence),
## trait de l'exigence du rôle ; rôle promis et humeur en pastilles.
class Barres extends Control:
	var matchs: Array = []
	var seuil: Variant = null
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		var haut := size.y - C.px(26)
		var n := 10
		var ecart := C.px(8)
		var l := (size.x - ecart * (n - 1)) / float(n)
		var echelle := 80.0
		for i in n:
			var x := i * (l + ecart)
			draw_rect(Rect2(x, 0, l, haut), Color(Charte.IVOIRE, .05))
			var k := i - (n - matchs.size())
			if k < 0: continue
			var m: Dictionary = matchs[k]
			var minutes := float(m.get("minutes", 0))
			var etat := str(m.get("etat", "neutre"))
			var hb := haut * clampf(minutes / echelle, 0.0, 1.0)
			draw_rect(Rect2(x, haut - hb, l, hb), TempsJeu.couleur_etat(etat))
			var t := "×" if etat == "absent" else str(int(minutes))
			var corps := maxi(11, C.px(16))
			var lt := C.BOLD.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
			draw_string(C.BOLD, Vector2(x + (l - lt) * .5, size.y - C.px(4)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, Charte.IVOIRE_2)
		if seuil is int or seuil is float:
			var y := haut - haut * clampf(float(seuil) / echelle, 0.0, 1.0)
			draw_line(Vector2(0, y), Vector2(size.x, y), Charte.IVOIRE, maxf(1.0, C.px(2)))

static func _temps_jeu(f: Control, zone: Rect2, tj: Dictionary, fiche: Callable) -> void:
	if tj.is_empty():
		D.text(f, zone.position.x + 8, zone.position.y + 50, "—", 30, Charte.IVOIRE_3, 700, 100)
		return
	var role := str(tj.get("role", ""))
	var x := zone.position.x + 8
	x += Pastilles.poser(f, Role.pastille(role, 18), x, zone.position.y + 6) + 10
	var h := str(tj.get("humeur", "neutre"))
	var hum: Array = TempsJeu.HUMEURS.get(h, TempsJeu.HUMEURS.neutre)
	Pastilles.poser(f, Pastilles.pastille("%s %s" % [hum[0], hum[1]], TempsJeu.couleur_humeur(h), "", "Temps de jeu promis : " + str(hum[1]), 18, "DiscussionTempsJeuHumeur", fiche), x, zone.position.y + 4)
	var exigence := str(TempsJeu.EXIGENCES.get(role, "—"))
	Pastilles.poser_a_droite(f, Pastilles.pastille(exigence, Charte.IVOIRE_2, "clock", "Exigence du rôle", 16, "DiscussionTempsJeuExigence"), zone.end.x - 8, zone.position.y + 6)
	var barres := Barres.new()
	barres.name = "DiscussionTempsJeuBarres"
	barres.matchs = tj.get("pastilles", []) if tj.get("pastilles") is Array else []
	barres.seuil = tj.get("seuil")
	barres.tooltip_text = "Minutes des 10 derniers matchs"
	f.add_child(barres)
	D.place(barres, Rect2(zone.position.x + 8, zone.position.y + 50, zone.size.x - 16, zone.size.y - 54))
