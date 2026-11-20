extends Control
## Presse : « La voix du club » (design/ux/06-presse.md, variante 3 « Synthèse à gauche » choisie par Léo le 19/11/2026).
## Colonne de gauche : l'image du club (médias, supporters, pression en verdict à trois paliers) et la salle de presse ;
## à droite : Journal (coupure de journal + résultats), Conférence, Historique, Portraits. Quand la conférence est tenue,
## la barre pleine largeur de la variante 2 remplace la carte « salle de presse ».
## Tout ce qui ressemble à un lien en est un : club → fiche du club, joueur → fiche (mini-fiche au survol),
## journaliste → ses Portraits, échange → son détail, score → la coupure. Aucune petite fenêtre.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const S = preload("res://ui/data_semantics.gd")
const Link = preload("res://ui/entity_link.gd")
const MiniFiche = preload("res://ui/immersive08/mini_fiche.gd")
const Commune = preload("res://ui/immersive08/fiche_commune.gd")
const Press = preload("res://ui/press_view.gd")
const WIDTH := 2248
const HEIGHT := 1240
const LEFT_W := 496
const RIGHT_X := 516
const RIGHT_W := WIDTH - RIGHT_X
const TABS := ["Journal", "Conférence", "Historique", "Portraits"]
const SLOTS := ["Journal", "Conférence", "Historique", "Relations"]
const BAR_H := 196

## Jauge à repère : piste, remplissage, repère de la valeur ; segments optionnels (verdict à trois paliers).
class Barre extends Control:
	var valeur := 0.0
	var couleur := Color.WHITE
	var segments: Array = []
	var seuil := -1.0

	func _draw() -> void:
		var haut := size.y
		if segments.is_empty():
			draw_rect(Rect2(0, 0, size.x, haut), Charte.PANNEAU_3)
			draw_rect(Rect2(0, 0, size.x * clampf(valeur / 100.0, 0.0, 1.0), haut), couleur)
			if seuil >= 0.0: draw_rect(Rect2(size.x * seuil / 100.0 - 1, -2, 2, haut + 4), Charte.IVOIRE_3)
		else:
			var trou := maxf(2.0, size.y * 0.35)
			for segment: Array in segments:
				var debut: float = float(segment[0])
				var fin: float = float(segment[1])
				var x0 := size.x * debut / 100.0
				var x1 := size.x * fin / 100.0 - trou
				draw_rect(Rect2(x0, 0, x1 - x0, haut), Charte.PANNEAU_3)
				var plein := clampf(valeur, debut, fin)
				if plein > debut: draw_rect(Rect2(x0, 0, (x1 - x0) * (plein - debut) / (fin - debut), haut), segment[2])
		var x := size.x * clampf(valeur / 100.0, 0.0, 1.0)
		draw_rect(Rect2(x - 1.5, -3, 3, size.y + 6), Charte.IVOIRE)

var app: Control
var data: Dictionary
var tabs: TabContainer
var controls: Array[Button] = []
var draft_status: Label
var draft_count: Label
var action: Button
var division_chooser: OptionButton
var active := 0

static func build(owner_app: Control, canvas: Control) -> void:
	var page: Control = load("res://ui/immersive08/press_canvas.gd").new()
	page.app = owner_app
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, WIDTH, HEIGHT))
	page._build()

func _build() -> void:
	name = "CarnetPresse"
	data = app.model.get("clubLife", {}).get("press", {})
	active = clampi(int(app.management_ui.get("press_tab", 0)), 0, TABS.size() - 1)
	_title()
	if data.is_empty():
		var vide := _boite(self, Rect2(0, 76, WIDTH, 300), "PressEmpty")
		vide.add_child(_titre("JOURNAL INDISPONIBLE", 34))
		vide.add_child(C.wrap("Le journal sera disponible après création d’une carrière.", 22, C.MUTED, false))
		return
	var tenue := _held_outcome()
	var top := 76 + (BAR_H + 20 if not tenue.is_empty() else 0)
	if not tenue.is_empty(): _held_bar(tenue)
	_left(top, not tenue.is_empty())
	_desk(top)

# --- Outils de composition ----------------------------------------------------------------------------------------

func _titre(texte: String, taille: int, couleur: Color = C.IVORY) -> Label:
	var label := C.label(texte, taille, couleur, true, 800)
	label.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	return label

func _petit(texte: String, taille: int = 16, couleur: Color = C.MUTED) -> Label:
	var label := C.label(texte.to_upper(), taille, couleur, true, 700)
	return label

func _texte(texte: String, taille: int = 18, couleur: Color = C.IVORY) -> Label:
	return C.wrap(texte, taille, couleur, false, 500)

func _surface(parent: Node, rect: Rect2, id: String, couleur: Color = C.PANEL) -> PanelContainer:
	var panneau := PanelContainer.new()
	panneau.name = id
	panneau.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = couleur
	style.set_corner_radius_all(0)
	panneau.add_theme_stylebox_override("panel", Charte.ombrer_droit(style))
	parent.add_child(panneau)
	D.place(panneau, rect)
	Charte.ombre_derriere(panneau) # le panneau rogne son contenu : l'ombre passe à un calque frère
	return panneau

func _boite(parent: Node, rect: Rect2, id: String, couleur: Color = C.PANEL, marge: int = 24) -> VBoxContainer:
	var panneau := _surface(parent, rect, id, couleur)
	var cadre := C.margin(marge)
	panneau.add_child(cadre)
	var colonne := C.v(10)
	cadre.add_child(colonne)
	return colonne

func _lien(texte: String, rappel: Callable, taille: int = 19, repos: bool = false, id: String = "", fleche: bool = false) -> Button:
	var bouton := Button.new()
	if not id.is_empty(): bouton.name = id
	bouton.text = texte + (" →" if fleche else "")
	bouton.focus_mode = Control.FOCUS_ALL
	C.style_bouton_lien(bouton, taille, repos)
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	bouton.pressed.connect(rappel)
	return bouton

## Lien sur fond ivoire (la coupure de journal) : texte et soulignement nuit.
func _sombre(bouton: Button) -> Button:
	for etat in ["normal", "hover", "pressed", "focus"]:
		var style := bouton.get_theme_stylebox(etat) as StyleBoxFlat
		if style != null: style.border_color = Charte.FOND
	for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		bouton.add_theme_color_override(cle, Charte.FOND)
	return bouton

func _club_lien(id: Variant, nom: String, taille: int = 19, sur_papier: bool = false) -> Control:
	if Link.available(app, "club", id):
		var bouton := _lien(nom, func(): pass, taille, true)
		Link.bind(bouton, app, Link.target("club", id), nom)
		bouton.tooltip_text = ""
		if sur_papier: _sombre(bouton)
		return bouton
	return _cellule(nom, 0, Charte.FOND if sur_papier else C.IVORY, false, taille)

func _joueur_lien(id: String, nom: String, taille: int = 19) -> Control:
	var source := "squad" if _dans_effectif(id) else ""
	var trouve: Dictionary = Commune.trouver(app, id, source)
	if trouve.is_empty() or not Link.available(app, "player", id):
		return _cellule(nom, 0, C.IVORY, false, taille)
	var bouton := _lien(nom, func(): pass, taille, true)
	Link.bind(bouton, app, Link.target("player", id), nom)
	MiniFiche.lier(app, bouton, id, str(trouve.source))
	return bouton

func _dans_effectif(id: String) -> bool:
	for player: Dictionary in app.model.get("squad", []):
		if str(player.get("id", "")) == id: return true
	return false

func _club_name(id: Variant) -> String:
	return Press._club(app, id)

func _cellule(texte: String, largeur: float, couleur: Color = C.IVORY, droite: bool = false, taille: int = 18) -> Label:
	var label := C.label(texte, taille, couleur, false, 500)
	label.custom_minimum_size = Vector2(C.px(largeur), C.px(32))
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if droite: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label

func _case(controle: Control, largeur: float) -> Control:
	controle.custom_minimum_size = Vector2(C.px(largeur), C.px(32))
	if controle is Button: (controle as Button).clip_text = true
	return controle

func _ligne(parent: Node, rang: int, choisie: bool = false) -> HBoxContainer:
	var fond := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C.SELECTED if choisie else (C.RAISED if rang % 2 == 1 else Color(0, 0, 0, 0))
	style.set_corner_radius_all(0)
	if choisie:
		style.border_color = C.IVORY
		style.border_width_left = maxi(2, C.px(4))
	style.content_margin_left = C.px(10)
	style.content_margin_right = C.px(10)
	fond.add_theme_stylebox_override("panel", style)
	var rang_h := C.h(8)
	fond.add_child(rang_h)
	parent.add_child(fond)
	return rang_h

func _entete(parent: Node, colonnes: Array) -> void:
	var rang := C.h(8)
	rang.custom_minimum_size.y = C.px(30)
	for colonne: Array in colonnes:
		var label := _petit(str(colonne[0]), 16, C.MUTED)
		label.custom_minimum_size.x = C.px(float(colonne[1]))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if float(colonne[1]) <= 0 else Control.SIZE_FILL
		if colonne.size() > 2: label.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_CENTER][int(colonne[2])]
		rang.add_child(label)
	var marge := C.margin(0)
	marge.add_theme_constant_override("margin_left", C.px(10))
	marge.add_theme_constant_override("margin_right", C.px(10))
	marge.add_child(rang)
	parent.add_child(marge)
	parent.add_child(C.rule())

func _titre_section(parent: Node, texte: String, lien: Control = null) -> void:
	var rang := C.h(8)
	var titre := _petit(texte, 18, C.IVORY)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rang.add_child(titre)
	if lien != null: rang.add_child(lien)
	parent.add_child(rang)

func _barre(valeur: float, couleur: Color, hauteur: int = 8, segments: Array = [], seuil: float = -1.0) -> Barre:
	var barre := Barre.new()
	barre.valeur = valeur
	barre.couleur = couleur
	barre.segments = segments
	barre.seuil = seuil
	barre.custom_minimum_size.y = maxi(5, C.px(hauteur))
	barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return barre

# --- En-tête, barre « conférence tenue », colonne de gauche -----------------------------------------------------

func _title() -> void:
	var ligne := C.h(22)
	add_child(ligne)
	D.place(ligne, Rect2(0, 6, 1300, 56))
	var titre := _titre("LA VOIX DU CLUB", 46)
	titre.name = "PressDeskTitle"
	ligne.add_child(titre)
	var sous := C.label("Troisième Mi-Temps.", 22, C.MUTED, false, 500)
	sous.size_flags_vertical = Control.SIZE_SHRINK_END
	ligne.add_child(sous)
	var context: Dictionary = data.get("context", {})
	var detail := G.club_name(app.model.club)
	if not context.is_empty():
		detail += "  ·  Saison " + G.season_label(context.get("season"))
		if S.count_text(context.get("week")) != "—": detail += "  ·  Semaine " + G.n(int(context.week) + 1)
	var droite := C.label(detail, 20, C.MUTED, false, 500)
	droite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(droite)
	D.place(droite, Rect2(WIDTH - 900, 22, 900, 34))

## Dernier retour de conférence de cette saison, quand plus rien n'est à préparer (état « conférence tenue »).
func _held_outcome() -> Dictionary:
	var conference: Dictionary = data.get("conference", {})
	var outcome: Variant = data.get("lastOutcome")
	if data.is_empty() or conference.get("available", false) or not outcome is Dictionary: return {}
	if int(outcome.context.season) != int(data.get("context", {}).get("season", -1)): return {}
	return outcome

func _held_bar(outcome: Dictionary) -> void:
	var colonne := _boite(self, Rect2(0, 76, WIDTH, BAR_H), "PressHeldBar", C.PANEL, 26)
	var rang := C.h(40)
	colonne.add_child(rang)
	var gauche := C.v(8)
	gauche.custom_minimum_size.x = C.px(520)
	rang.add_child(gauche)
	var statut := C.h(10)
	var marque := ColorRect.new()
	marque.color = C.IVORY
	marque.custom_minimum_size = Vector2(C.px(5), C.px(30))
	marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	statut.add_child(marque)
	var titre := _titre("CONFÉRENCE TENUE", 34)
	titre.name = "PressConferenceState"
	statut.add_child(titre)
	gauche.add_child(statut)
	gauche.add_child(_texte("Semaine %d · %s" % [int(outcome.context.week) + 1, _club_name(outcome.context.club)], 19, C.MUTED))
	action = _lien("Consulter le compte rendu", func(): _select(1), 21, false, "OpenPressConference", true)
	C.style_bouton_contour(action, 21)
	action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	gauche.add_child(action)
	draft_status = C.label("", 18, C.MUTED, false, 500)
	draft_status.name = "PressDraftStatus"
	gauche.add_child(draft_status)
	var tuiles := C.h(18)
	tuiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rang.add_child(tuiles)
	for entree: Array in [["morale", "Moral"], ["trust", "Direction"], ["mediaTrust", "Médias"], ["fanTrust", "Supporters"], ["boardPressure", "Pression"]]:
		var cle: String = entree[0]
		var avant: float = float(outcome.before.get(cle, 0))
		var apres: float = float(outcome.after.get(cle, 0))
		var delta: float = float(outcome.delta.get(cle, 0))
		var tuile := C.v(4)
		tuile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tuile.add_child(_petit(str(entree[1]), 16, C.MUTED))
		tuile.add_child(C.label("%d → %d" % [roundi(avant), roundi(apres)], 34, C.IVORY, true, 700))
		tuile.add_child(C.label("%+d" % roundi(delta), 22, _couleur_delta(cle, delta), true, 700))
		tuiles.add_child(tuile)
	_update_draft()

func _couleur_delta(cle: String, delta: float) -> Color:
	if is_zero_approx(delta): return C.MUTED
	var bon := delta > 0 if cle != "boardPressure" else delta < 0
	return Charte.V if bon else Charte.D

func _left(top: int, tenue: bool) -> void:
	_image_card(top)
	var bas := top + 490
	if tenue: _memory_card(Rect2(0, bas, LEFT_W, HEIGHT - bas))
	else: _room_card(Rect2(0, bas, LEFT_W, HEIGHT - bas))

func _image_card(top: int) -> void:
	var colonne := _boite(self, Rect2(0, top, LEFT_W, 470), "PressImage", C.PANEL, 24)
	colonne.add_child(_titre("TON IMAGE", 30))
	var metrics: Dictionary = data.get("metrics", {})
	_indicateur(colonne, "Médias", metrics.get("mediaTrust"), ["hostiles", "méfiants", "corrects", "favorables"], "PressMetricMedia")
	_indicateur(colonne, "Supporters", metrics.get("fanTrust"), ["mécontents", "inquiets", "confiants", "fervents"], "PressMetricFans")
	_pression(colonne, metrics.get("boardPressure"))

func _tier(valeur: float) -> int:
	return 0 if valeur < 30 else (1 if valeur < 50 else (2 if valeur < 70 else 3))

func _indicateur(parent: Node, titre: String, brut: Variant, mots: Array, id: String) -> void:
	var cadre := C.v(5)
	cadre.name = id
	var texte := S.count_text(brut)
	var rang := C.h(8)
	var etiquette := _petit(titre, 17, C.IVORY)
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rang.add_child(etiquette)
	if texte == "—":
		rang.add_child(C.label("—", 20, C.MUTED, false, 600))
		cadre.add_child(rang)
		parent.add_child(cadre)
		return
	var valeur := float(brut)
	var palier := _tier(valeur)
	var couleur: Color = [Charte.D, Charte.ATTRIBUT_40, Charte.V, Charte.V][palier]
	rang.add_child(C.label("%s / 100" % texte, 20, C.IVORY, false, 700))
	rang.add_child(C.label(str(mots[palier]), 20, couleur, false, 700))
	cadre.add_child(rang)
	cadre.add_child(_barre(valeur, couleur, 8, [], 50.0))
	parent.add_child(cadre)

func _pression(parent: Node, brut: Variant) -> void:
	var cadre := C.v(6)
	cadre.name = "PressMetricPressure"
	var texte := S.count_text(brut)
	var rang := C.h(8)
	var etiquette := _petit("Pression", 17, C.IVORY)
	etiquette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rang.add_child(etiquette)
	if texte == "—":
		rang.add_child(C.label("—", 20, C.MUTED, false, 600))
		cadre.add_child(rang)
		parent.add_child(cadre)
		return
	var valeur := float(brut)
	rang.add_child(C.label("%s / 100" % texte, 20, C.IVORY, false, 700))
	cadre.add_child(rang)
	var palier := 0 if valeur < 50 else (1 if valeur < 70 else 2)
	var couleur: Color = [Charte.V, Charte.ATTRIBUT_40, Charte.D][palier]
	var verdict := C.h(8)
	var symbole := C.icon("check" if palier == 0 else "warning", 24, couleur)
	verdict.add_child(symbole)
	var mot := _titre(["CALME", "SOUS TENSION", "TEMPÊTE"][palier], 30, couleur)
	mot.name = "PressPressureVerdict"
	verdict.add_child(mot)
	cadre.add_child(verdict)
	cadre.add_child(_barre(valeur, couleur, 8, [[0, 50, Charte.V], [50, 70, Charte.ATTRIBUT_40], [70, 100, Charte.D]]))
	var legende := C.h(0)
	for entree: Array in [["0-49", 50], ["50-69", 20], ["70+", 30]]:
		var borne := C.label(str(entree[0]), 16, C.MUTED, false, 500)
		borne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		borne.size_flags_stretch_ratio = float(entree[1])
		legende.add_child(borne)
	cadre.add_child(legende)
	cadre.add_child(_texte("Sous tension à partir de 50, tempête à partir de 70.", 16, C.MUTED))
	parent.add_child(cadre)

func _room_card(rect: Rect2) -> void:
	var colonne := _boite(self, rect, "PressConferenceBrief", C.PANEL, 24)
	colonne.add_child(_titre("LA SALLE DE PRESSE", 30))
	var conference: Dictionary = data.get("conference", {})
	var available: bool = conference.get("available", false)
	var questions: Array = conference.get("questions", [])
	# Ouverte depuis le rail (sans le courrier d'invitation) : la conférence reste derrière son courrier.
	var invited: bool = available and str(app.get_meta("press_mail_origin", "")) == str(conference.get("invitationId", ""))
	var statut := C.h(10)
	var marque := ColorRect.new()
	marque.color = C.IVORY
	marque.custom_minimum_size = Vector2(C.px(5), C.px(28))
	marque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	statut.add_child(marque)
	var etat := ("CONFÉRENCE OUVERTE" if invited else "UNE CONFÉRENCE T’ATTEND") if available else "PAS DE CONFÉRENCE CETTE SEMAINE"
	var titre := _titre(etat, 26)
	titre.name = "PressStatusTitle"
	statut.add_child(titre)
	colonne.add_child(statut)
	if available and invited:
		var chiffres := C.h(26)
		var brouillon: Dictionary = app.get_meta("press_draft_choices", {})
		for entree: Array in [[questions.size(), "questions"], [brouillon.size(), "en brouillon"]]:
			var bloc := C.v(0)
			var nombre := C.label(str(entree[0]), 50, C.IVORY, true, 700)
			if str(entree[1]) == "en brouillon": draft_count = nombre
			bloc.add_child(nombre)
			bloc.add_child(C.label(str(entree[1]), 18, C.MUTED, false, 500))
			chiffres.add_child(bloc)
		colonne.add_child(chiffres)
	var moment: Variant = conference.get("moment")
	var contexte := ""
	if available:
		contexte = str(moment.get("label", "")) if moment is Dictionary else ""
		if not invited: contexte = (contexte + " · " if not contexte.is_empty() else "") + "Ouvre son invitation dans la Réception."
	else:
		contexte = str(conference.get("reason", "Le journal et les archives restent consultables."))
	var detail := _texte(contexte, 18, C.MUTED)
	detail.name = "PressConferenceState" if not available or not invited else "PressConferenceMoment"
	colonne.add_child(detail)
	draft_status = C.label("", 18, C.MUTED, false, 600)
	draft_status.name = "PressDraftStatus"
	colonne.add_child(draft_status)
	if available and not invited:
		action = _lien("Ouvrir la Réception", func(): app._navigate("Réception"), 21, false, "OpenPressConference", true)
	else:
		var legende := "Préparer la conférence" if available else ("Consulter le compte rendu" if data.get("lastOutcome") is Dictionary else "Voir l’historique")
		var cible := 1 if available or data.get("lastOutcome") is Dictionary else 2
		action = _lien(legende, func(): _select(cible), 21, false, "OpenPressConference", true)
	action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	colonne.add_child(action)
	_update_draft()
	colonne.add_child(C.rule())
	_memory_block(colonne)

func _memory_card(rect: Rect2) -> void:
	var colonne := _boite(self, rect, "PressMemoryBrief", C.PANEL, 24)
	_memory_block(colonne)

func _memory_block(colonne: VBoxContainer) -> void:
	colonne.add_child(_petit("Mémoire des échanges", 18, C.IVORY))
	var history: Array = data.get("history", [])
	var people: Array = data.get("people", [])
	colonne.add_child(_texte("%d déclaration(s) conservée(s) · %d journaliste(s)" % [history.size(), people.size()], 18, C.IVORY))
	var liens := C.h(14)
	liens.add_child(_lien("Historique", func(): _select(2), 19, false, "OpenPressHistory", true))
	liens.add_child(_lien("Portraits", func(): _select(3), 19, false, "OpenPressPeople", true))
	colonne.add_child(liens)
	var policy: Dictionary = data.get("policy", {})
	if policy.is_empty(): return
	colonne.add_child(C.rule())
	colonne.add_child(_petit("Conférences ordinaires", 16, C.MUTED))
	var actuel := str(policy.get("ordinary", "moi"))
	var choix := C.h(10)
	for option: Array in [["moi", "Y aller"], ["adjoint", "Envoyer l’adjoint"]]:
		var cle: String = option[0]
		var bouton := _lien(str(option[1]), func(): _set_policy(cle), 18, cle == actuel, "PressPolicy_" + cle)
		if cle == actuel: bouton.text = "✓ " + bouton.text
		choix.add_child(bouton)
	colonne.add_child(choix)
	if not str(policy.get("notice", "")).is_empty(): colonne.add_child(_texte(str(policy.get("notice", "")), 16, C.MUTED))

func _set_policy(key: String) -> void:
	if app.waiting or str(data.get("policy", {}).get("ordinary", "moi")) == key: return
	app._command("press_policy", {"ordinary":key})

# --- Bureau : onglets et contenu ----------------------------------------------------------------------------------

func _desk(top: int) -> void:
	for i in TABS.size():
		var bouton := Button.new()
		bouton.name = "PressCanvasTab" + str(i)
		bouton.text = TABS[i]
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.custom_minimum_size = Vector2.ZERO
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(bouton)
		D.place(bouton, Rect2(RIGHT_X + i * 250, top, 240, 56))
		var index := i
		bouton.pressed.connect(func(): _select(index))
		controls.append(bouton)
	_mark_tabs()
	division_chooser = _build_division_chooser()
	if division_chooser != null:
		add_child(division_chooser)
		D.place(division_chooser, Rect2(WIDTH - 420, top + 4, 420, 48))
		_mark_tabs()
	var cadre := _surface(self, Rect2(RIGHT_X, top + 64, RIGHT_W, HEIGHT - top - 64), "PressDesk")
	tabs = TabContainer.new()
	tabs.name = "PressTabs"
	tabs.tabs_visible = false
	tabs.clip_contents = true
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var marge := C.margin(20)
	cadre.add_child(marge)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marge.add_child(tabs)
	if data.conference.get("available", false): Press._conference_draft(app, data)
	for titre in SLOTS:
		var slot := Control.new()
		slot.name = titre
		tabs.add_child(slot)
	tabs.current_tab = active
	_mount(active)
	tabs.tab_changed.connect(func(index: int):
		active = index
		app.management_ui.press_tab = index
		_mount(index)
		_mark_tabs())
	_update_draft()

func _mark_tabs() -> void:
	for i in controls.size():
		var choisi := i == active
		var bouton := controls[i]
		for etat in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = C.SELECTED if choisi else (C.RAISED if etat in ["hover", "hover_pressed"] else Color(0, 0, 0, 0))
			style.set_corner_radius_all(0)
			style.border_color = C.IVORY
			style.border_width_bottom = maxi(2, C.px(4)) if choisi or etat == "focus" else 0
			style.content_margin_left = C.px(16)
			style.content_margin_right = C.px(16)
			bouton.add_theme_stylebox_override(etat, style)
		for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			bouton.add_theme_color_override(cle, C.IVORY if choisi else C.MUTED)
		bouton.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE if choisi else C.BOLD)
		bouton.add_theme_font_size_override("font_size", maxi(14, C.px(24)))
	if division_chooser != null: division_chooser.visible = active == 0
	_style_action()

## Un seul ivoire plein par écran : « Préparer la conférence » cède la place à « Publier mes réponses » dans l'onglet Conférence.
func _style_action() -> void:
	if action == null or not is_instance_valid(action) or action.name != "OpenPressConference": return
	if active != 1: C.style_bouton_contour(action, 21)
	else:
		C.style_bouton_lien(action, 21, false)
		action.add_theme_font_override("font", Charte.texte_moyen())

func _select(index: int) -> void:
	if tabs != null: tabs.current_tab = index

func _remount(index: int) -> void:
	if tabs == null: return
	var slot := tabs.get_tab_control(index)
	for enfant in slot.get_children():
		slot.remove_child(enfant)
		enfant.queue_free()
	_mount(index)

func _mount(index: int) -> void:
	var slot := tabs.get_tab_control(index)
	if slot.get_child_count() != 0: return
	var page: Control
	match index:
		0: page = _journal_page()
		1: page = _conference_page()
		2: page = _history_page()
		3: page = _people_page()
		_: return
	slot.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for answer: Button in page.find_children("PressAnswer_*", "Button", true, false):
		answer.pressed.connect(_update_draft)
	if app.get_window() != null: C.reach_controls(page)

func _update_draft() -> void:
	if draft_status == null or not is_instance_valid(draft_status): return
	var draft: Dictionary = app.get_meta("press_draft_choices", {}) if data.conference.get("available", false) else {}
	draft_status.text = "%d réponse(s) en brouillon" % draft.size() if not draft.is_empty() else ""
	if draft_count != null and is_instance_valid(draft_count): draft_count.text = str(draft.size())

func _defile(nom: String) -> VBoxContainer:
	var defilement := ScrollContainer.new()
	defilement.name = nom
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defilement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var colonne := C.v(14)
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(colonne)
	defilement.set_meta("colonne", colonne)
	return colonne

func _racine(colonne: Control) -> Control:
	return colonne.get_parent() as Control

# --- Journal ---------------------------------------------------------------------------------------------------

func _build_division_chooser() -> OptionButton:
	var divisions: Array = data.get("journal", {}).get("divisions", [])
	var choix := OptionButton.new()
	choix.name = "PressDivision"
	choix.focus_mode = Control.FOCUS_ALL
	choix.add_theme_font_override("font", C.BODY)
	choix.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	for etat in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = C.SELECTED if etat != "hover" else C.RAISED
		style.set_corner_radius_all(0)
		style.content_margin_left = C.px(14)
		style.content_margin_right = C.px(14)
		if etat == "focus":
			style.bg_color = Color(0, 0, 0, 0)
			style.set_border_width_all(2)
			style.border_color = C.IVORY
		choix.add_theme_stylebox_override(etat, style)
	for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		choix.add_theme_color_override(cle, C.IVORY)
	var popup := choix.get_popup()
	var fond := StyleBoxFlat.new()
	fond.bg_color = C.PANEL
	fond.set_corner_radius_all(0)
	popup.add_theme_stylebox_override("panel", fond)
	popup.add_theme_color_override("font_color", C.IVORY)
	popup.add_theme_color_override("font_hover_color", C.IVORY)
	popup.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
	var noms := {}
	for league: Dictionary in app.model.get("leagues", []):
		noms[league.id] = str(league.get("name", league.id))
	for division: Dictionary in divisions:
		choix.add_item(str(division.get("label", noms.get(division.id, "Championnat"))))
	var initial := clampi(int(app.management_ui.get("press_division", -1)), -1, maxi(0, divisions.size() - 1))
	if initial < 0:
		initial = 0
		for index in divisions.size():
			if divisions[index].id == app.model.meta.get("leagueId", "historical"):
				initial = index
				break
	if not divisions.is_empty(): choix.select(initial)
	choix.item_selected.connect(func(index: int):
		app.management_ui.press_division = index
		app.management_ui.erase("press_article")
		_remount(0))
	return choix

func _division() -> Dictionary:
	var divisions: Array = data.get("journal", {}).get("divisions", [])
	if divisions.is_empty() or division_chooser == null: return {}
	return divisions[clampi(division_chooser.selected, 0, divisions.size() - 1)]

func _phase_label(phase: Variant) -> String:
	return {"league":"championnat", "barrage":"barrage", "semi":"demi-finale", "final":"finale", "access":"barrage d’accession"}.get(str(phase), "compétition")

func _journal_page() -> Control:
	var colonne := _defile("Journal")
	var division := _division()
	if division.is_empty():
		colonne.add_child(_texte("Aucun fait sportif enregistré.", 20, C.MUTED))
		return _racine(colonne)
	var resultats: Array = division.get("results", [])
	var rang := C.h(28)
	rang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_child(rang)
	var article := _article(resultats)
	if not article.is_empty():
		var papier := _papier(article, division)
		papier.size_flags_stretch_ratio = 1.3
		rang.add_child(papier)
	var droite := C.v(16)
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rang.add_child(droite)
	_resultats(droite, resultats, article)
	# Les indisponibilités se rangent sous la coupure : les deux colonnes se répartissent la hauteur.
	var gauche := rang.get_child(0) as Control
	if gauche.name == "PressPaper":
		rang.remove_child(gauche)
		var pile := C.v(18)
		pile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pile.size_flags_stretch_ratio = 1.3
		pile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		pile.add_child(gauche)
		_indispos(pile, division.get("injuries", []))
		rang.add_child(pile)
		rang.move_child(pile, 0)
	else: _indispos(droite, division.get("injuries", []))
	return _racine(colonne)

func _article(resultats: Array) -> Dictionary:
	if resultats.is_empty(): return {}
	var choisi := str(app.management_ui.get("press_article", ""))
	var propre := int(app.model.club.get("id", -1))
	for resultat: Dictionary in resultats:
		if str(resultat.get("id", "")) == choisi: return resultat
	for resultat: Dictionary in resultats:
		if propre == int(resultat.clubIds[0]) or propre == int(resultat.clubIds[1]): return resultat
	return resultats[0]

func _papier(resultat: Dictionary, division: Dictionary) -> Control:
	var fond := PanelContainer.new()
	fond.name = "PressPaper"
	var style := StyleBoxFlat.new()
	style.bg_color = Charte.IVOIRE
	style.set_corner_radius_all(0)
	style.content_margin_left = C.px(28)
	style.content_margin_right = C.px(28)
	style.content_margin_top = C.px(24)
	style.content_margin_bottom = C.px(28)
	fond.add_theme_stylebox_override("panel", style)
	fond.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fond.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var colonne := C.v(10)
	fond.add_child(colonne)
	var entete := C.h(12)
	var journal := C.label(_outlet().to_upper(), 40, Charte.FOND, true, 800)
	journal.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	journal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal.clip_text = true
	entete.add_child(journal)
	var date := C.label("SEMAINE %d · SPORT" % (int(resultat.week) + 1), 16, Charte.PANNEAU_3, true, 700)
	entete.add_child(date)
	colonne.add_child(entete)
	var filet := ColorRect.new()
	filet.color = Charte.FOND
	filet.custom_minimum_size.y = maxi(2, C.px(3))
	colonne.add_child(filet)
	var propre := int(app.model.club.get("id", -1))
	var domicile: int = int(resultat.clubIds[0])
	var exterieur: int = int(resultat.clubIds[1])
	var points_d: int = int(resultat.score[0])
	var points_e: int = int(resultat.score[1])
	var nom_d := _club_name(domicile)
	var nom_e := _club_name(exterieur)
	colonne.add_child(C.label("LES FAITS DU TERRAIN · %s · %s" % [str(division.get("label", "Compétition")).to_upper(), _phase_label(resultat.get("phase")).to_upper()], 16, Charte.PANNEAU_3, true, 700))
	var titre := ""
	if points_d == points_e: titre = "Match nul %d-%d entre %s et %s" % [points_d, points_e, nom_d, nom_e]
	else:
		var gagnant := domicile if points_d > points_e else exterieur
		var perdant := exterieur if gagnant == domicile else domicile
		var haut := maxi(points_d, points_e)
		var bas := mini(points_d, points_e)
		if propre in [gagnant, perdant]:
			titre = "%s s’impose %d-%d %s %s" % [_club_name(gagnant), haut, bas, "à" if gagnant == exterieur else "face à", _club_name(perdant)] if gagnant == propre else "%s s’incline %d-%d %s %s" % [_club_name(propre), bas, haut, "à" if propre == exterieur else "face à", _club_name(gagnant)]
		else: titre = "%s l’emporte %d-%d sur %s" % [_club_name(gagnant), haut, bas, _club_name(perdant)]
	var gros := C.wrap(titre.to_upper(), 58, Charte.FOND, true, 800)
	gros.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	gros.name = "PressHeadline"
	colonne.add_child(gros)
	var ecart := absi(points_d - points_e)
	var chapeau := "%s recevait %s : %d-%d, %s." % [nom_d, nom_e, points_d, points_e, "un match nul" if ecart == 0 else ("un écart de %d point(s)" % ecart)]
	colonne.add_child(C.wrap(chapeau, 21, Charte.FOND, false, 500))
	var place := _position_texte(division.get("standings", []), propre)
	if not place.is_empty(): colonne.add_child(C.wrap(place, 19, Charte.PANNEAU_3, false, 500))
	var separation := ColorRect.new()
	separation.color = Charte.PANNEAU_3
	separation.custom_minimum_size.y = maxi(1, C.px(2))
	colonne.add_child(separation)
	var score := C.h(6)
	score.add_child(C.label("SCORE", 16, Charte.PANNEAU_3, true, 700))
	score.add_child(_club_lien(domicile, nom_d, 19, true))
	score.add_child(C.label("%d-%d" % [points_d, points_e], 19, Charte.FOND, false, 700))
	score.add_child(_club_lien(exterieur, nom_e, 19, true))
	colonne.add_child(score)
	return fond

func _position_texte(standings: Array, club: int) -> String:
	for ligne: Dictionary in standings:
		if int(ligne.get("clubId", -1)) == club:
			return "%s est %s au classement avec %d points en %d match(s)." % [_club_name(club), "1er" if int(ligne.rank) == 1 else "%de" % int(ligne.rank), int(ligne.points), int(ligne.played)]
	return ""

func _outlet() -> String:
	var meilleur := ""
	var rencontres := -1
	for person: Dictionary in data.get("people", []):
		if int(person.get("encounters", 0)) > rencontres:
			rencontres = int(person.get("encounters", 0))
			meilleur = str(person.get("outlet", ""))
	return meilleur if not meilleur.is_empty() else "La Voix du club"

func _resultats(parent: Node, resultats: Array, article: Dictionary) -> void:
	var classement := _lien("Voir le classement", func(): app._navigate("Classements"), 19, false, "PressRankingLink", true)
	_titre_section(parent, "Les résultats conservés", classement)
	if resultats.is_empty():
		parent.add_child(_texte("Aucun résultat enregistré dans cette division. Le premier coup d’envoi ouvrira le journal.", 19, C.MUTED))
		return
	_entete(parent, [["Domicile", 0], ["Score", 110, 2], ["Extérieur", 0]])
	var rang := 0
	for resultat: Dictionary in resultats.slice(0, 14):
		var choisi: bool = str(resultat.get("id", "")) == str(article.get("id", ""))
		var ligne := _ligne(parent, rang, choisi)
		rang += 1
		var domicile := _club_lien(resultat.clubIds[0], _club_name(resultat.clubIds[0]), 19)
		_case(domicile, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(domicile)
		var identifiant := str(resultat.get("id", ""))
		var score := _lien("%d – %d" % [int(resultat.score[0]), int(resultat.score[1])], func():
			app.management_ui.press_article = identifiant
			_remount(0), 19, false, "PressResult_" + identifiant.validate_node_name())
		score.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_case(score, 110)
		ligne.add_child(score)
		var exterieur := _club_lien(resultat.clubIds[1], _club_name(resultat.clubIds[1]), 19)
		_case(exterieur, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(exterieur)

func _indispos(parent: Node, blessures: Array) -> void:
	if blessures.is_empty(): return
	_titre_section(parent, "Indisponibilités enregistrées")
	_entete(parent, [["Joueur", 0], ["Club", 0], ["Durée", 90, 1]])
	var rang := 0
	for blessure: Dictionary in blessures.slice(0, 12):
		var ligne := _ligne(parent, rang)
		rang += 1
		var nom := str(blessure.get("playerName", blessure.get("playerId", "")))
		var joueur := _joueur_lien(str(blessure.get("playerId", "")), nom, 19)
		_case(joueur, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(joueur)
		var club := _club_lien(blessure.get("clubId"), _club_name(blessure.get("clubId")), 19)
		_case(club, 0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ligne.add_child(club)
		ligne.add_child(_cellule("%d sem." % int(blessure.get("weeks", 0)), 90, C.MUTED, true))

# --- Conférence ------------------------------------------------------------------------------------------------

func _conference_page() -> Control:
	var colonne := _defile("Conférence")
	var conference: Dictionary = data.conference
	var outcome: Variant = data.get("lastOutcome")
	var origin := str(app.get_meta("press_mail_origin", ""))
	if not origin.is_empty() and (origin == conference.get("invitationId") or (outcome is Dictionary and origin == outcome.get("invitationId"))):
		colonne.add_child(_lien("Revenir au courrier", func():
			app.remove_meta("press_mail_origin")
			app._navigate("Réception", false), 19, false, "PressBackToInvitation", true))
	var ouverte: bool = conference.available and origin == conference.get("invitationId")
	# Conférence ouverte : les questions passent d'abord, le retour de la précédente se range en bas.
	if outcome is Dictionary and not ouverte: _outcome_block(colonne, outcome)
	if not ouverte:
		if conference.available:
			colonne.add_child(_texte("Ouvre l’invitation dans la Réception pour répondre aux questions.", 20, C.IVORY))
			colonne.add_child(_lien("Ouvrir l’invitation", func(): app._navigate("Réception"), 21, false, "PressOpenInvitation", true))
		else:
			colonne.add_child(_texte(str(conference.reason), 20, C.IVORY))
		return _racine(colonne)
	colonne.add_child(_texte("Cinq tons. Tabulation pour parcourir les choix, Espace pour sélectionner. Publier valide toutes tes réponses.", 18, C.MUTED))
	var memoire := _texte("Les relances reprennent tes échanges précédents avec ce journaliste, dans ce club et cette saison.", 18, C.MUTED)
	memoire.name = "PressMemoryNotice"
	colonne.add_child(memoire)
	var choices: Dictionary = Press._conference_draft(app, data)
	var publier := Button.new()
	publier.name = "PressSubmit"
	publier.text = "Publier mes réponses"
	publier.focus_mode = Control.FOCUS_ALL
	C.style_bouton_contour(publier, 22)
	publier.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	publier.disabled = choices.size() != conference.questions.size()
	var manque := C.label("", 19, C.MUTED, false, 600)
	manque.name = "PressSubmitMissing"
	var majuscule := func() -> void:
		var reste: int = conference.questions.size() - choices.size()
		manque.text = "" if reste <= 0 else "Il reste %d question(s) sans réponse." % reste
		publier.disabled = reste > 0
	publier.set_meta("rafraichir", majuscule)
	var inactif := StyleBoxFlat.new()
	inactif.bg_color = C.SELECTED
	inactif.set_corner_radius_all(0)
	inactif.content_margin_left = C.px(18)
	inactif.content_margin_right = C.px(18)
	inactif.content_margin_top = C.px(7)
	inactif.content_margin_bottom = C.px(7)
	publier.add_theme_stylebox_override("disabled", inactif)
	publier.pressed.connect(func():
		var answers: Array = []
		for question: Dictionary in conference.questions: answers.append({"questionId":question.id, "answerId":choices[question.id]})
		app._command("press_conference", {"context":data.context, "answers":answers, "invitationId":origin}))
	for question: Dictionary in conference.questions:
		colonne.add_child(_question_block(question, choices, publier, conference.questions.find(question)))
	var bas := C.h(18)
	bas.add_child(publier)
	manque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bas.add_child(manque)
	majuscule.call()
	colonne.add_child(bas)
	var delegation: Dictionary = conference.get("delegation", {})
	if bool(delegation.get("allowed", false)):
		# Conséquence écrite en clair, confirmation en ligne (aucune fenêtre).
		var bloc := C.v(6)
		bloc.add_child(_texte(str(delegation.get("reason", "")), 17, C.MUTED))
		var rang := C.h(16)
		var confirmer := _lien("Confirmer : Gabi répond à ma place", func(): app._command("press_delegate", {"context":data.context, "invitationId":origin}), 19, false, "PressDelegate", true)
		confirmer.visible = false
		var annuler := _lien("Annuler", func(): pass, 19, false, "PressDelegateCancel")
		annuler.visible = false
		var proposer := _lien("Laisser Gabi répondre", func(): pass, 20, false, "PressDelegateAsk", true)
		proposer.pressed.connect(func():
			proposer.visible = false
			confirmer.visible = true
			annuler.visible = true)
		annuler.pressed.connect(func():
			proposer.visible = true
			confirmer.visible = false
			annuler.visible = false)
		rang.add_child(proposer)
		rang.add_child(confirmer)
		rang.add_child(annuler)
		bloc.add_child(rang)
		colonne.add_child(bloc)
	elif not str(delegation.get("reason", "")).is_empty():
		colonne.add_child(_texte("Gabi ne peut pas répondre à ta place : " + str(delegation.get("reason", "")), 17, C.MUTED))
	if outcome is Dictionary:
		colonne.add_child(C.rule())
		_outcome_block(colonne, outcome)
	return _racine(colonne)

func _outcome_block(colonne: VBoxContainer, outcome: Dictionary) -> void:
	colonne.add_child(_petit("Retour de la dernière conférence · saison %s · semaine %d" % [G.season_label(outcome.context.season), int(outcome.context.week) + 1], 18, C.IVORY))
	var delta: Dictionary = outcome.delta
	var tuiles := C.h(26)
	for entree: Array in [["morale", "Moral"], ["trust", "Direction"], ["mediaTrust", "Médias"], ["fanTrust", "Supporters"], ["boardPressure", "Pression"]]:
		var cle: String = entree[0]
		var bloc := C.h(8)
		bloc.add_child(C.label(str(entree[1]), 18, C.MUTED, false, 500))
		bloc.add_child(C.label("%+d" % roundi(float(delta.get(cle, 0))), 22, _couleur_delta(cle, float(delta.get(cle, 0))), true, 700))
		tuiles.add_child(bloc)
	colonne.add_child(tuiles)
	var echanges: Array = outcome.get("exchanges", [])
	if not echanges.is_empty():
		var retour := C.v(2)
		retour.name = "PressRelationshipOutcome"
		colonne.add_child(retour)
		for echange: Dictionary in echanges:
			var identifiant := str(echange.journalistId)
			var nom := identifiant
			for person: Dictionary in data.get("people", []):
				if person.id == echange.journalistId: nom = str(person.name); break
			var rang := C.h(8)
			rang.add_child(_journaliste_lien(identifiant, nom, 19))
			rang.add_child(C.label("relation %+d → %+d (%+d)" % [roundi(float(echange.before)), roundi(float(echange.after)), roundi(float(echange.delta))], 18, Charte.V if float(echange.delta) >= 0 else Charte.D, false, 600))
			retour.add_child(rang)
	colonne.add_child(C.rule())

func _question_block(question: Dictionary, choices: Dictionary, publier: Button, index: int) -> Control:
	var fond := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C.RAISED
	style.set_corner_radius_all(0)
	style.content_margin_left = C.px(22)
	style.content_margin_right = C.px(22)
	style.content_margin_top = C.px(18)
	style.content_margin_bottom = C.px(18)
	fond.add_theme_stylebox_override("panel", style)
	fond.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var carte := C.v(8)
	fond.add_child(carte)
	var tete := C.h(14)
	tete.add_child(_titre("QUESTION %02d" % (index + 1), 24))
	var journaliste: Dictionary = question.journalist
	tete.add_child(_journaliste_lien(str(journaliste.id), str(journaliste.name), 22))
	var provenance := C.label(str(journaliste.outlet), 19, C.MUTED, false, 500)
	provenance.name = "PressIdentity_" + str(question.id)
	tete.add_child(provenance)
	carte.add_child(tete)
	carte.add_child(_texte("Style d’entretien : %s · %s" % [journaliste.styleLabel, journaliste.personality], 17, C.MUTED))
	var relation := _texte("%s · relation %+d / 100 · %d échange(s) avec toi" % [question.relation.label, roundi(float(question.relation.score)), int(question.relation.encounters)], 17, C.IVORY)
	relation.name = "PressRelation_" + str(question.id)
	carte.add_child(relation)
	if question.get("followUp") is Dictionary:
		var source := _texte(str(question.followUp.get("label", "Déclaration archivée dans cette carrière")), 17, C.MUTED)
		source.name = "PressFollowUp_" + str(question.id)
		carte.add_child(source)
	carte.add_child(_texte(str(question.question), 21, C.IVORY))
	var groupe := ButtonGroup.new()
	for reponse: Dictionary in question.answers:
		var legende := "%s · %s\n%s" % [str(reponse.toneLabel).to_upper(), reponse.text, reponse.consequence]
		var option := Button.new()
		option.name = "PressAnswer_" + str(question.id) + "_" + str(reponse.id)
		option.text = legende
		option.toggle_mode = true
		option.button_group = groupe
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.focus_mode = Control.FOCUS_ALL
		option.custom_minimum_size.y = C.px(70)
		option.tooltip_text = ""
		_style_reponse(option)
		option.button_pressed = choices.get(question.id, "") == reponse.id
		option.icon = C.icon_texture("check", C.IVORY) if option.button_pressed else null
		var identifiant: Variant = reponse.id
		var question_id: Variant = question.id
		option.toggled.connect(func(actif: bool): option.icon = C.icon_texture("check", C.IVORY) if actif else null)
		option.pressed.connect(func():
			choices[question_id] = identifiant
			if publier.has_meta("rafraichir"): publier.get_meta("rafraichir").call()
			else: publier.disabled = choices.size() != data.conference.questions.size())
		carte.add_child(option)
	return fond

func _style_reponse(option: Button) -> void:
	for etat in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = C.PANEL
		if etat in ["hover", "pressed", "hover_pressed"]: style.bg_color = C.SELECTED
		style.set_corner_radius_all(0)
		style.content_margin_left = C.px(18)
		style.content_margin_right = C.px(18)
		style.content_margin_top = C.px(8)
		style.content_margin_bottom = C.px(8)
		if etat in ["pressed", "hover_pressed"]:
			style.border_color = C.IVORY
			style.border_width_left = maxi(3, C.px(6))
		if etat == "focus":
			style.bg_color = Color(0, 0, 0, 0)
			style.set_border_width_all(2)
			style.border_color = C.IVORY
		option.add_theme_stylebox_override(etat, style)
	for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		option.add_theme_color_override(cle, C.IVORY)
	option.add_theme_font_override("font", C.BODY)
	option.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	option.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	option.expand_icon = true
	option.add_theme_constant_override("icon_max_width", C.px(22))
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _journaliste_lien(id: String, nom: String, taille: int = 19) -> Button:
	var bouton := _lien(nom, func(): _open_person(id), taille, true, "PressPersonLink_" + id.validate_node_name())
	bouton.accessibility_name = "Ouvrir · " + nom
	return bouton

func _open_person(id: String) -> void:
	app.management_ui.press_person = id
	if tabs.current_tab == 3: _remount(3)
	else:
		_remount(3)
		_select(3)

# --- Historique ---------------------------------------------------------------------------------------------------

func _echange_cle(ligne: Dictionary) -> String:
	return "%s:%s:%s:%s" % [str(ligne.get("season", "")), str(ligne.get("week", "")), str(ligne.get("club", "")), str(ligne.get("id", ligne.get("questionId", "")))]

func _open_exchange(cle: String) -> void:
	app.management_ui.press_exchange = cle
	_remount(2)
	_select(2)

func _history_page() -> Control:
	var colonne := _defile("Historique")
	var lignes: Array = data.get("history", []).duplicate()
	lignes.reverse()
	if lignes.is_empty():
		colonne.add_child(_texte("Tu n’as encore publié aucune conférence.", 20, C.MUTED))
		return _racine(colonne)
	var choisi_cle := str(app.management_ui.get("press_exchange", ""))
	var choisi: Dictionary = lignes[0]
	for ligne: Dictionary in lignes:
		if _echange_cle(ligne) == choisi_cle: choisi = ligne
	var rang := C.h(28)
	colonne.add_child(rang)
	var liste := C.v(0)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rang.add_child(liste)
	_titre_section(liste, "Déclarations archivées")
	_entete(liste, [["Quand", 120], ["Journaliste", 0]])
	var index := 0
	for ligne: Dictionary in lignes:
		var cle := _echange_cle(ligne)
		var quand := "S%d · %s" % [int(ligne.week) + 1, G.season_label(ligne.season)]
		var qui := str(ligne.journalist.name) if ligne.has("journalist") else "Journaliste non conservé"
		var bouton := _ligne_bouton("%s    %s" % [quand, qui], cle == _echange_cle(choisi), index, "PressExchange_" + cle.validate_node_name(), func(): _open_exchange(cle))
		liste.add_child(bouton)
		index += 1
	var detail := C.v(10)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rang.add_child(detail)
	_titre_section(detail, "Échange")
	var contexte := C.h(10)
	contexte.add_child(C.label("Saison %s · semaine %d" % [G.season_label(choisi.season), int(choisi.week) + 1], 19, C.MUTED, false, 500))
	if choisi.has("club"): contexte.add_child(_club_lien(choisi.club, _club_name(choisi.club), 19))
	detail.add_child(contexte)
	if choisi.has("journalist"):
		var qui := C.h(10)
		qui.add_child(_journaliste_lien(str(choisi.journalist.id), str(choisi.journalist.name), 24))
		qui.add_child(C.label(str(choisi.journalist.outlet), 19, C.MUTED, false, 500))
		detail.add_child(qui)
	else:
		detail.add_child(_texte("Identité du journaliste non conservée dans cette ancienne conférence.", 18, C.MUTED))
	if bool(choisi.get("delegated", false)): detail.add_child(_texte("Réponse donnée par Gabi.", 18, C.MUTED))
	detail.add_child(_petit("Question", 16, C.MUTED))
	detail.add_child(_texte(str(choisi.question) if choisi.question != null else "Question d’origine non conservée dans cette ancienne conférence.", 21, C.IVORY))
	detail.add_child(_petit("Ta réponse", 16, C.MUTED))
	detail.add_child(_texte(str(choisi.answer) if choisi.answer != null else "Texte de la réponse non conservé · choix enregistré : " + str(choisi.get("answerId", "")), 20, C.IVORY))
	return _racine(colonne)

func _ligne_bouton(texte: String, choisie: bool, rang: int, id: String, rappel: Callable) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.text = texte
	bouton.clip_text = true
	bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.custom_minimum_size.y = C.px(34)
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for etat in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = C.SELECTED if choisie or etat in ["pressed", "hover_pressed"] else (C.RAISED if etat == "hover" or rang % 2 == 1 else Color(0, 0, 0, 0))
		style.set_corner_radius_all(0)
		style.content_margin_left = C.px(14)
		style.content_margin_right = C.px(10)
		if choisie:
			style.border_color = C.IVORY
			style.border_width_left = maxi(2, C.px(4))
		if etat == "focus":
			style.bg_color = Color(0, 0, 0, 0)
			style.set_border_width_all(2)
			style.border_color = C.IVORY
		bouton.add_theme_stylebox_override(etat, style)
	for cle in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(cle, C.IVORY)
	bouton.add_theme_font_override("font", C.BODY)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	bouton.pressed.connect(rappel)
	return bouton

# --- Portraits -------------------------------------------------------------------------------------------------

func _people_page() -> Control:
	var colonne := _defile("Relations")
	var gens: Array = data.get("people", [])
	if gens.is_empty():
		colonne.add_child(_texte("Aucun journaliste disponible.", 20, C.MUTED))
		return _racine(colonne)
	var voulu := str(app.management_ui.get("press_person", ""))
	var choisi: Dictionary = {}
	for person: Dictionary in gens:
		if str(person.id) == voulu: choisi = person
	if choisi.is_empty():
		for person: Dictionary in gens:
			if int(person.encounters) > 0: choisi = person; break
	if choisi.is_empty(): choisi = gens[0]
	var rang := C.h(28)
	colonne.add_child(rang)
	var liste := C.v(0)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rang.add_child(liste)
	_titre_section(liste, "Tes relations avec les journalistes")
	_entete(liste, [["Journaliste", 0], ["Relation", 228, 1]])
	var index := 0
	for person: Dictionary in gens:
		var id := str(person.id)
		var bouton := _ligne_bouton("%s · %s" % [person.name, person.outlet], id == str(choisi.id), index, "PressPerson_" + id.validate_node_name(), func():
			app.management_ui.press_person = id
			_remount(3))
		# Vraie colonne « Relation » : valeur signée et mot, alignés à droite dans la ligne.
		var relation := C.label("%+d · %s" % [roundi(float(person.score)), str(person.relationLabel)], 18, C.IVORY, false, 600)
		relation.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		relation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bouton.add_child(relation)
		relation.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		relation.offset_left = -C.px(240)
		relation.offset_right = -C.px(12)
		bouton.clip_text = true
		liste.add_child(bouton)
		index += 1
	var detail := C.v(10)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rang.add_child(detail)
	var identite := C.h(16)
	var initiales := ""
	for mot: String in str(choisi.get("name", "?")).split(" ", false):
		if initiales.length() < 2: initiales += mot.left(1)
	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = C.SELECTED
	badge_style.set_corner_radius_all(0)
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.custom_minimum_size = Vector2(C.px(64), C.px(64))
	var lettres := C.label(initiales.to_upper(), 28, C.IVORY, true, 800)
	lettres.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lettres.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(lettres)
	identite.add_child(badge)
	var noms := C.v(2)
	noms.add_child(_titre(str(choisi.name).to_upper(), 34))
	noms.add_child(C.label(str(choisi.outlet), 20, C.MUTED, false, 500))
	identite.add_child(noms)
	detail.add_child(identite)
	detail.add_child(_texte("Style d’entretien : %s · %s" % [choisi.styleLabel, choisi.personality], 19, C.IVORY))
	var specialites: Array[String] = []
	for sujet: String in choisi.get("specialties", []):
		if not specialites.has(sujet.replace("_", " ")): specialites.append(sujet.replace("_", " "))
	if not specialites.is_empty(): detail.add_child(_texte("Spécialités : " + ", ".join(specialites), 18, C.MUTED))
	detail.add_child(C.rule())
	var score := float(choisi.score)
	var mot_relation := C.label("%s · relation %+d / 100 · %d échange(s)" % [choisi.relationLabel, roundi(score), int(choisi.encounters)], 20, C.IVORY, false, 700)
	detail.add_child(mot_relation)
	detail.add_child(_barre((score + 100.0) / 2.0, Charte.V if score > 5 else (Charte.D if score < -5 else Charte.N), 8, [], 50.0))
	detail.add_child(_texte("De −100 à +100. L’accueil dépend du style du journaliste, du ton et du sujet.", 16, C.MUTED))
	if choisi.memory.is_empty():
		detail.add_child(_texte("Aucun échange individuel conservé. Les anciennes conférences sans identité ne créent pas de souvenir.", 18, C.MUTED))
	else:
		detail.add_child(_petit("Les trois derniers échanges", 18, C.IVORY))
		var memoire: Array = choisi.memory.duplicate()
		memoire.reverse()
		for echange: Dictionary in memoire:
			var cle := "%s:%s:%s:%s" % [str(echange.season), str(echange.week), str(echange.club), str(echange.questionId)]
			var question := str(echange.question) if echange.question != null else "Question d’origine non conservée."
			var entree := _lien("Saison %s · semaine %d · %s · %s (%+d)\n%s" % [G.season_label(echange.season), int(echange.week) + 1, _club_name(echange.club), echange.toneLabel, roundi(float(echange.delta)), question], func(): _open_exchange(cle), 18, false, "PressMemory_" + cle.validate_node_name())
			entree.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			entree.clip_text = false
			detail.add_child(entree)
	return _racine(colonne)
