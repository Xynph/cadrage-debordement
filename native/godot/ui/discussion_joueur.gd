extends RefCounted
## Discussion avec un joueur (revue FM27, idée 23) : petite fenêtre ouverte depuis Vestiaire › Entretiens et duos.
## Planche A/B sous CD_VARIANTE_VISUELLE (sans variante, l'écran garde ses trois lignes d'entretien).
##  A « face à face » : bandeau portrait + attitude + hiérarchie + bulle du joueur, ses données à gauche, nos mots à droite.
##  B « fil de discussion » : échelle d'attitude, ligne de données façon Effectif, fil de bulles, réponses en bas.
## Données : moteur relationships.cjs (satisfaction, confiance envers le coach, condition, minutes, trait, leadership,
## entretien disponible, effets) et notes de match (5 dernières notes). L'attitude est la satisfaction lue en six
## paliers ; pendant la discussion, le trait du joueur fait monter ou baisser d'un palier selon nos mots (affichage).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const V = preload("res://ui/relationships_visuals.gd")
const G = preload("res://ui/carnet_skin.gd")
const NotesMatch = preload("res://ui/notes_match.gd")
const Tableau = preload("res://ui/contextual/match_tableau_widgets.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")

const NOM := "DiscussionFenetre"
const CLE := "discussion"
## Paliers d'attitude (satisfaction) : mot, couleur, icône.
const ATTITUDES := [["Fermé", Pastilles.ROUGE, "warning"], ["Mécontent", Pastilles.ORANGE, "warning"], ["Inexpressif", Charte.IVOIRE_2, "info"],
	["Neutre", Pastilles.BLEU, "people"], ["Content", Pastilles.VERT, "check"], ["Enthousiaste", Pastilles.TURQUOISE, "star"]]
const SEUILS := [30, 45, 55, 65, 80]
## Nos mots (commande relationship_conversation) : phrase courte, icône et couleur de V.REPONSES.
const PHRASES := {"ecouter": "Dis-moi comment tu te sens.", "rassurer": "On compte sur toi, ta place viendra.", "clarifier": "Voilà ce que j'attends de toi."}
const ORDRE := ["ecouter", "rassurer", "clarifier"]
const BONUS := {"ecouter": 2, "rassurer": 1, "clarifier": 0}
## Réaction du trait (living-locker-room : TRAITS) à nos mots : +1 palier, 0, −1.
const REACTIONS := {
	"ecouter": {"Sensible": 1, "Discret": 1, "Loyal": 1, "Exigeant": -1},
	"rassurer": {"Sensible": 1, "Loyal": 1, "Protecteur": 1, "Collectif": 1, "Competiteur": -1},
	"clarifier": {"Exigeant": 1, "Ambitieux": 1, "Competiteur": 1, "Sensible": -1}}
const REPONSES := {
	"ecouter": {1: "Merci de prendre le temps, coach.", 0: "Ça va. Je bosse.", -1: "Je préfère parler sur le terrain."},
	"rassurer": {1: "Ça me fait du bien. Je serai prêt.", 0: "On verra sur le terrain.", -1: "J'attends des actes, coach."},
	"clarifier": {1: "C'est clair. Je sais quoi faire.", 0: "Compris.", -1: "J'avais déjà compris."}}
const ACCUEIL := "Oui, coach ?"

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func palier(score: Variant) -> int:
	if not (score is int or score is float): return 2
	var n := 0
	for s: int in SEUILS:
		if float(score) >= s: n += 1
	return n

## Carte « Discuter » de la colonne du joueur (remplace les trois lignes d'entretien sous variante).
static func bouton(app: Control, p: Dictionary) -> Control:
	var att: Array = ATTITUDES[palier(p.get("score"))]
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
	if not p.get("conversationAvailable", false):
		var vu := Pastilles.pastille("Vu", Charte.IVOIRE_2, "clock", "Entretien de la semaine fait", 16)
		vu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(vu)
	var fleche := C.label("›", 26, Charte.IVOIRE_2, true, 700)
	fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(fleche)
	var id := str(p.get("id", ""))
	return V.carte(ligne, func(): ouvrir(app, id), "DiscussionOuvrir", "Discuter", Pastilles.BLEU)

## Rouvre la fenêtre après un nouveau rendu du Vestiaire (réponse du moteur).
static func reprendre(app: Control, canvas: Control) -> void:
	if variante().is_empty(): return
	var etat: Variant = app.management_ui.get(CLE)
	if etat is Dictionary and not str(etat.get("id", "")).is_empty(): _dessiner(app, canvas, str(etat.id))

static func ouvrir(app: Control, id: String) -> void:
	var etat: Variant = app.management_ui.get(CLE)
	if not (etat is Dictionary and str(etat.get("id", "")) == id): app.management_ui[CLE] = {"id": id}
	var canvas := app.find_child("ImmersiveLockerRoom", true, false) as Control
	if canvas != null: _dessiner(app, canvas, id)

static func _oublier(app: Control) -> void:
	app.management_ui.erase(CLE)

## Données du joueur pour la fenêtre ; {} si le joueur n'est plus suivi.
static func donnees(app: Control, id: String) -> Dictionary:
	var rel: Dictionary = app.model.get("clubLife", {}).get("relationships", {})
	var players: Array = rel.get("players", [])
	var p: Dictionary = {}
	for x: Dictionary in players:
		if str(x.get("id")) == id: p = x
	if p.is_empty(): return {}
	var identite: Dictionary = {"id": id}
	for s: Dictionary in app.model.get("squad", []):
		if str(s.get("id")) == id: identite = s
	# Hiérarchie : rang de leadership dans le groupe suivi ; relais pressenti, cadres (5 premiers), jeunes (21 ans et moins).
	var rangs := players.duplicate()
	rangs.sort_custom(func(a, b): return _leadership(a) > _leadership(b))
	var rang := 1
	for i in rangs.size():
		if str(rangs[i].get("id")) == id: rang = i + 1
	var statut := ["Groupe", Pastilles.BLEU, "people"]
	if str(rel.get("leaderId", "")) == id: statut = ["Relais", Pastilles.VIOLET, "star"]
	elif rang <= 5: statut = ["Cadre", Pastilles.VIOLET, "star"]
	elif int(identite.get("age", 30)) <= 21: statut = ["Jeune", Pastilles.TURQUOISE, "people"]
	var personnalite: Variant = p.get("personality")
	var trait_nom := str(personnalite.get("trait", "")) if personnalite is Dictionary else ""
	var detail := {}
	for c: Dictionary in rel.get("conversations", []): detail[str(c.id)] = str(c.detail)
	var etat: Dictionary = app.management_ui.get(CLE, {}) if app.management_ui.get(CLE) is Dictionary else {}
	return {"id": id, "p": p, "identite": identite, "nom": str(identite.get("name", "Joueur")), "poste": str(p.get("pos", "")),
		"score": p.get("score"), "confiance": p.get("trust"), "condition": int(p.get("condition", 0)), "minutes": p.get("minutes"),
		"trait": trait_nom, "rang": rang, "total": players.size(), "statut": statut, "forme": NotesMatch.forme(NotesMatch.joueur(app.model, id)),
		"libre": bool(p.get("conversationAvailable", false)) and not etat.has("choix"), "contexte": rel.get("context", {}), "effets": detail, "etat": etat}

static func _leadership(p: Dictionary) -> float:
	var x: Variant = p.get("personality")
	return float(x.get("leadership", 0)) if x is Dictionary and x.get("leadership") != null else 0.0

## Nos mots : réponse immédiate dans la fenêtre, commande du moteur, la fenêtre revient au nouveau rendu.
static func _choisir(app: Control, d: Dictionary, choix: String) -> void:
	var avant: Variant = d.score
	var apres: Variant = clampi(int(avant) + int(BONUS.get(choix, 0)), 20, 95) if (avant is int or avant is float) else avant
	var reaction := int(REACTIONS.get(choix, {}).get(d.trait, 0))
	var depart := palier(avant)
	var arrivee := clampi(palier(apres) + reaction, 0, ATTITUDES.size() - 1)
	app.management_ui[CLE] = {"id": d.id, "choix": choix, "avant": avant, "apres": apres, "depart": depart, "arrivee": arrivee, "reaction": reaction}
	ouvrir(app, str(d.id))
	app._command("relationship_conversation", {"context": d.contexte, "playerId": d.id, "choice": choix})

static func _fiche(app: Control, id: String) -> Callable:
	var nav: Variant = app.get("navigation_controller")
	var cible := {"kind": "player", "id": id}
	if not is_instance_valid(nav) or not nav.has_method("entity_available") or not nav.entity_available(cible): return Callable()
	return func():
		Fenetre.fermer(app, NOM)
		_oublier(app)
		nav.open_entity(cible)

static func _dessiner(app: Control, canvas: Control, id: String) -> void:
	var d := donnees(app, id)
	if d.is_empty():
		_oublier(app)
		return
	if variante() == "B": _dessiner_b(app, canvas, d)
	else: _dessiner_a(app, canvas, d)

## ---- Pièces communes ---------------------------------------------------------------------------

static func _portrait(app: Control, parent: Control, d: Dictionary, zone: Rect2, id: String) -> void:
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
	bouton.name = id
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
	CarteSurvol.lier(app, bouton, str(d.id), "squad")

static func _attitude(index: int, taille: int = 20, id: String = "") -> Control:
	var a: Array = ATTITUDES[clampi(index, 0, ATTITUDES.size() - 1)]
	return Pastilles.pastille(str(a[0]), a[1], str(a[2]), "Attitude : " + str(a[0]), taille, id)

static func _hierarchie(d: Dictionary, taille: int = 18) -> Control:
	var s: Array = d.statut
	return Pastilles.pastille("%s · %de / %d" % [s[0], d.rang, d.total], s[1], s[2], "Hiérarchie du vestiaire (leadership)", taille, "DiscussionHierarchie")

## Bulle de parole : fond teinté, texte sur une ligne ; `droite` = bulle du coach.
static func _bulle(parent: Control, zone: Rect2, texte: String, couleur: Color, id: String, taille: int = 24) -> Panel:
	var bulle := D.rect(parent, zone, Color(couleur, .22), Charte.RAYON_CARTE)
	bulle.name = id
	var mot := D.text(bulle, 22, zone.size.y * .5 + taille * .36, texte, taille, Charte.IVOIRE, 600, zone.size.x - 44, HORIZONTAL_ALIGNMENT_LEFT, true)
	mot.name = id + "Texte"
	return bulle

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
	courbe.notes = notes
	var textes: Array[String] = []
	for n: Variant in notes: textes.append(NotesMatch.texte_note(n))
	courbe.tooltip_text = "Forme : " + (" · ".join(textes) if not textes.is_empty() else "aucun match noté")
	parent.add_child(courbe)
	D.place(courbe, zone)
	return courbe

static func _section(parent: Control, x: float, base: float, texte: String, icone: String, couleur: Color) -> void:
	var image := C.icon(icone, 22, couleur)
	parent.add_child(image)
	D.place(image, Rect2(x, base - 20, 22, 22))
	D.text(parent, x + 32, base, texte.to_upper(), 20, Charte.IVOIRE_2, 700, 400)

## ---- Option A : face à face ------------------------------------------------------------------------

static func _dessiner_a(app: Control, canvas: Control, d: Dictionary) -> void:
	var L := 1660.0
	var H := 930.0
	var f := Fenetre.ouvrir(canvas, NOM, "Discussion", "people", L, H, func(): _oublier(app))
	var etat: Dictionary = d.etat
	var parle := etat.has("choix")
	# Bandeau : portrait, nom, hiérarchie, trait, poste ; attitude à droite ; bulle du joueur.
	D.rect(f, Rect2(28, 84, L - 56, 214), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	_portrait(app, f, d, Rect2(52, 104, 174, 174), "DiscussionPortrait")
	_nom(app, f, d, 254, 158, 52, 760)
	var x := 254.0
	var fiche := _fiche(app, str(d.id))
	if not str(d.poste).is_empty(): x += Pastilles.poser(f, Pastilles.pastille(str(d.poste), Charte.IVOIRE_2, "people", "Poste", 18, "DiscussionPoste", fiche), x, 178) + 10
	x += Pastilles.poser(f, _hierarchie(d), x, 178) + 10
	if not str(d.trait).is_empty(): Pastilles.poser(f, Pastilles.pastille(str(d.trait), Pastilles.VIOLET, "people", "Personnalité", 18, "DiscussionTrait"), x, 178)
	var reponse := ACCUEIL
	if parle: reponse = str(REPONSES.get(etat.choix, {}).get(int(etat.reaction), ACCUEIL))
	_bulle(f, Rect2(254, 228, 900, 54), reponse, Pastilles.BLEU, "DiscussionBulleJoueur", 24)
	D.text(f, L - 52, 128, "ATTITUDE", 18, Charte.IVOIRE_3, 700, 300, HORIZONTAL_ALIGNMENT_RIGHT)
	if parle and int(etat.depart) != int(etat.arrivee):
		var arrivee := _attitude(int(etat.arrivee), 24, "DiscussionAttitude")
		var largeur := Pastilles.poser_a_droite(f, arrivee, L - 52, 146)
		D.text(f, L - 52 - largeur - 14, 176, "›", 34, Charte.IVOIRE_2, 800, 30, HORIZONTAL_ALIGNMENT_RIGHT)
		var avant := _attitude(int(etat.depart), 18, "DiscussionAttitudeAvant")
		avant.modulate = Color(1, 1, 1, .55)
		Pastilles.poser_a_droite(f, avant, L - 52 - largeur - 52, 150)
	else:
		Pastilles.poser_a_droite(f, _attitude(int(etat.get("arrivee", palier(d.score))), 24, "DiscussionAttitude"), L - 52, 146)
	if parle:
		var effet := int(etat.apres) - int(etat.avant) if (etat.avant is int or etat.avant is float) else 0
		var signe := "▲ +%d" % effet if effet > 0 else "= 0"
		Pastilles.poser_a_droite(f, Pastilles.pastille("%s satisf. · %d → %d" % [signe, int(etat.avant), int(etat.apres)], Pastilles.VERT if effet > 0 else Charte.IVOIRE_2, "heart", "Satisfaction", 18, "DiscussionEffet"), L - 52, 228)
	# Colonne gauche : ses données.
	var gauche := D.rect(f, Rect2(28, 318, 900, H - 346), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	gauche.name = "DiscussionDonnees"
	_section(f, 52, 366, "Forme · 5 derniers matchs", "rating", Charte.IVOIRE_2)
	_courbe(f, Rect2(52, 384, 852, 230), d.forme)
	_section(f, 52, 662, "Lui et le coach", "heart", Pastilles.BLEU)
	var rangee := C.h(18)
	rangee.name = "DiscussionJauges"
	var score := float(d.score) if (d.score is int or d.score is float) else 0.0
	if parle and (etat.apres is int or etat.apres is float): score = float(etat.apres)
	rangee.add_child(V.anneau(score, "Satisf.", "heart", V.teinte(score), "DiscussionAnneauSatisfaction", fiche))
	rangee.add_child(V.anneau(float(d.confiance) if (d.confiance is int or d.confiance is float) else 0.0, "Confiance", "shield", Charte.CONFIANCE, "DiscussionAnneauConfiance", fiche))
	var tuiles := C.v(10)
	for t: Control in [Pastilles.tuile("%d %%" % int(d.condition), "condition", Pastilles.VERT if d.condition >= 80 else (Pastilles.ORANGE if d.condition >= 50 else Pastilles.ROUGE), Charte.PANNEAU_3, 30, "DiscussionCondition", false, fiche),
			Pastilles.tuile(str(int(d.minutes)) if (d.minutes is int or d.minutes is float) else "—", "minutes", Pastilles.TURQUOISE, Charte.PANNEAU_3, 30, "DiscussionMinutes", false, fiche)]:
		t.custom_minimum_size.x = C.px(170)
		tuiles.add_child(t)
	rangee.add_child(tuiles)
	Pastilles.poser(f, rangee, 60, 684)
	# Colonne droite : nos mots.
	D.rect(f, Rect2(948, 318, L - 976, H - 346), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	_section(f, 972, 366, "Tes mots", "mail", Charte.IVOIRE_2)
	var y := 390.0
	for choix: String in ORDRE:
		var style: Array = V.REPONSES.get(choix, ["check", Pastilles.BLEU])
		var colonne := C.v(8)
		var tete := C.h(12)
		var icone := C.icon(style[0], 30, style[1])
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete.add_child(icone)
		var phrase := C.label(str(PHRASES[choix]), 24, Charte.IVOIRE, false, 600)
		phrase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tete.add_child(phrase)
		colonne.add_child(tete)
		colonne.add_child(V.effets(str(d.effets.get(choix, "")), 16))
		colonne.custom_minimum_size = Vector2(C.px(L - 1060), 0)
		var choisi := parle and str(etat.choix) == choix
		var carte := V.carte(colonne, func(): _choisir(app, d, choix), "DiscussionPhrase_" + choix, str(PHRASES[choix]), style[1], d.libre, choisi)
		if parle and not choisi: carte.modulate = Color(1, 1, 1, .35)
		f.add_child(carte)
		D.place(carte, Rect2(972, y, L - 1020, 136))
		y += 156
	if not d.libre and not parle:
		Pastilles.poser(f, Pastilles.pastille("Entretien de la semaine fait", Charte.IVOIRE_2, "clock", "Un entretien par joueur et par semaine", 18, "DiscussionDejaVu"), 972, y + 4)

## ---- Option B : fil de discussion --------------------------------------------------------------------

static func _dessiner_b(app: Control, canvas: Control, d: Dictionary) -> void:
	var L := 1240.0
	var H := 1060.0
	var f := Fenetre.ouvrir(canvas, NOM, "Discussion", "people", L, H, func(): _oublier(app))
	var etat: Dictionary = d.etat
	var parle := etat.has("choix")
	var fiche := _fiche(app, str(d.id))
	# Tête : portrait, nom, poste + hiérarchie + trait.
	_portrait(app, f, d, Rect2(32, 84, 128, 128), "DiscussionPortrait")
	_nom(app, f, d, 184, 140, 46, 700)
	var x := 184.0
	if not str(d.poste).is_empty(): x += Pastilles.poser(f, Pastilles.pastille(str(d.poste), Charte.IVOIRE_2, "people", "Poste", 18, "DiscussionPoste", fiche), x, 166) + 10
	x += Pastilles.poser(f, _hierarchie(d), x, 166) + 10
	if not str(d.trait).is_empty(): Pastilles.poser(f, Pastilles.pastille(str(d.trait), Pastilles.VIOLET, "people", "Personnalité", 18, "DiscussionTrait"), x, 166)
	# Échelle d'attitude : six paliers colorés, le palier courant en plein ; l'ancien barré d'une flèche.
	var depart := int(etat.get("depart", palier(d.score)))
	var arrivee := int(etat.get("arrivee", depart))
	var echelle := Control.new()
	echelle.name = "DiscussionEchelleAttitude"
	f.add_child(echelle)
	D.place(echelle, Rect2(32, 236, L - 64, 74))
	var case_l := (L - 64 - 5 * 8) / 6.0
	for i in ATTITUDES.size():
		var a: Array = ATTITUDES[i]
		var actif := i == arrivee
		var fond := D.rect(echelle, Rect2(i * (case_l + 8), 0, case_l, 50), Color(a[1], .9 if actif else (.3 if i == depart and depart != arrivee else .12)), Charte.RAYON_PETIT)
		fond.name = "DiscussionPalier%d" % i
		var couleur_texte: Color = Charte.ENCRE if actif else (a[1] if i == depart else Color(a[1], .7))
		D.text(fond, case_l * .5, 33, str(a[0]), 20, couleur_texte, 700, case_l, HORIZONTAL_ALIGNMENT_CENTER)
	if depart != arrivee:
		var a0 := depart * (case_l + 8) + case_l * .5
		var a1 := arrivee * (case_l + 8) + case_l * .5
		D.rect(echelle, Rect2(minf(a0, a1), 60, absf(a1 - a0), 5), Charte.IVOIRE, 2)
		D.text(echelle, a1 + (10 if a1 > a0 else -30), 72, "▶" if a1 > a0 else "◀", 18, Charte.IVOIRE, 800, 22)
	# Ligne de données façon Effectif : en-têtes discrets, chiffres colorés, toute la ligne ouvre la fiche.
	var cols := [["FORME", 32.0, 300.0], ["SATISF.", 380.0, 150.0], ["CONFIANCE", 560.0, 170.0], ["CONDITION", 760.0, 170.0], ["MINUTES", 960.0, 150.0], ["HIÉRARCHIE", 1110.0, 100.0]]
	D.rect(f, Rect2(20, 324, L - 40, 40), Charte.BANDEAU_ENTETE, Charte.RAYON_PETIT)
	for c: Array in cols: D.text(f, c[1], 351, c[0], 17, Charte.IVOIRE_3, 700, c[2])
	var ligne := D.rect(f, Rect2(20, 368, L - 40, 76), Charte.PANNEAU_2, Charte.RAYON_PETIT)
	ligne.name = "DiscussionLigne"
	NotesMatch.pastilles(f, Vector2(32, 392), d.forme, Vector2(50, 30), 6.0, 0.42)
	var score: Variant = etat.get("apres", d.score) if parle else d.score
	var chiffres := [[str(int(score)) if (score is int or score is float) else "—", V.teinte(score), 380.0],
		[str(int(d.confiance)) if (d.confiance is int or d.confiance is float) else "—", Charte.CONFIANCE, 560.0],
		["%d %%" % int(d.condition), Pastilles.VERT if d.condition >= 80 else (Pastilles.ORANGE if d.condition >= 50 else Pastilles.ROUGE), 760.0],
		[str(int(d.minutes)) if (d.minutes is int or d.minutes is float) else "—", Pastilles.TURQUOISE, 960.0],
		["%de" % int(d.rang), Pastilles.VIOLET, 1110.0]]
	for c: Array in chiffres: D.text(f, c[2], 420, c[0], 34, c[1], 800, 170)
	if parle and (etat.avant is int or etat.avant is float) and int(etat.apres) != int(etat.avant):
		D.text(f, 440, 420, "▲ +%d" % (int(etat.apres) - int(etat.avant)), 20, Pastilles.VERT, 800, 100)
	if fiche.is_valid():
		var survol := Button.new()
		survol.name = "DiscussionLigneFiche"
		survol.flat = true
		survol.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var vide := StyleBoxFlat.new()
		vide.bg_color = Color.TRANSPARENT
		var dessus := StyleBoxFlat.new()
		dessus.bg_color = Color(Charte.IVOIRE, .06)
		dessus.set_corner_radius_all(C.px(Charte.RAYON_PETIT))
		survol.add_theme_stylebox_override("normal", vide)
		survol.add_theme_stylebox_override("hover", dessus)
		survol.add_theme_stylebox_override("pressed", dessus)
		survol.add_theme_stylebox_override("focus", vide)
		survol.tooltip_text = str(d.nom)
		survol.pressed.connect(fiche)
		f.add_child(survol)
		D.place(survol, Rect2(20, 368, L - 40, 76))
		CarteSurvol.lier(app, survol, str(d.id), "squad")
	# Fil de discussion : le joueur à gauche (petit visage), le coach à droite.
	var fil := D.rect(f, Rect2(20, 464, L - 40, 380), Charte.PANNEAU_2, Charte.RAYON_CARTE)
	fil.name = "DiscussionFil"
	var y := 488.0
	_visage(f, d, Rect2(40, y, 56, 56))
	_bulle(f, Rect2(110, y, 560, 56), ACCUEIL, Pastilles.BLEU, "DiscussionBulleAccueil", 24)
	if parle:
		var style: Array = V.REPONSES.get(str(etat.choix), ["check", Pastilles.BLEU])
		y += 84
		_bulle(f, Rect2(L - 40 - 20 - 640, y, 640, 56), str(PHRASES.get(str(etat.choix), "")), style[1], "DiscussionBulleCoach", 24)
		y += 84
		_visage(f, d, Rect2(40, y, 56, 56))
		_bulle(f, Rect2(110, y, 640, 56), str(REPONSES.get(etat.choix, {}).get(int(etat.reaction), "")), Pastilles.BLEU, "DiscussionBulleJoueur", 24)
		y += 80
		Pastilles.poser(f, V.effets(str(d.effets.get(str(etat.choix), "")), 18), 110, y)
	# Réponses : trois pilules en bas, de la couleur du ton ; une fois parlé, « Terminer ».
	var bas := 866.0
	if parle:
		var fin := D.button(f, Rect2((L - 320) / 2.0, bas + 30, 320, 72), "Terminer", func(): Fenetre.fermer(canvas, NOM), false, "check")
		fin.name = "DiscussionTerminer"
		return
	var largeur := (L - 40 - 2 * 16) / 3.0
	for i in ORDRE.size():
		var choix: String = ORDRE[i]
		var style: Array = V.REPONSES.get(choix, ["check", Pastilles.BLEU])
		var colonne := C.v(6)
		var tete := C.h(10)
		var icone := C.icon(style[0], 26, style[1])
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete.add_child(icone)
		var phrase := C.wrap(str(PHRASES[choix]), 21, Charte.IVOIRE, false, 600)
		phrase.custom_minimum_size.x = C.px(largeur - 90)
		tete.add_child(phrase)
		colonne.add_child(tete)
		colonne.add_child(V.effets(str(d.effets.get(choix, "")), 15))
		var carte := V.carte(colonne, func(): _choisir(app, d, choix), "DiscussionPhrase_" + choix, str(PHRASES[choix]), style[1], d.libre)
		f.add_child(carte)
		D.place(carte, Rect2(20 + i * (largeur + 16), bas, largeur, 150))
	if not d.libre:
		Pastilles.poser(f, Pastilles.pastille("Entretien de la semaine fait", Charte.IVOIRE_2, "clock", "Un entretien par joueur et par semaine", 18, "DiscussionDejaVu"), 110, 780)

static func _visage(parent: Control, d: Dictionary, zone: Rect2) -> void:
	var fond := D.rect(parent, zone, Charte.PANNEAU_3, int(zone.size.x * .5))
	fond.clip_contents = true
	var visage := G.portrait(int(d.identite.get("portraitIndex", posmod(str(d.id).hash(), 32))), C.px(zone.size.x), d.identite)
	visage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(visage)
	visage.position = Vector2.ZERO
	visage.size = zone.size * C.density

## Les mots auxquels ce trait réagit le mieux (captures de la planche).
static func meilleur_choix(trait_nom: String) -> String:
	for choix: String in ORDRE:
		if int(REACTIONS.get(choix, {}).get(trait_nom, 0)) > 0: return choix
	return "ecouter"
