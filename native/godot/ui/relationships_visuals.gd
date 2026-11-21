extends RefCounted
## Pièces visuelles de Vestiaire › Entretiens et duos (revue du 21/11/2026, n° 4, option B « portraits et anneaux »
## choisie par Léo). Règles : aucune phrase d'explication (le texte du moteur reste en infobulle), effets en pastilles ▲ / ▼
## colorées, couleur jamais seule (flèche, icône ou mot), toute carte et tout portrait cliquables.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const Pastilles = preload("res://ui/immersive08/pastilles_club.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const G = preload("res://ui/carnet_skin.gd")

const LIBELLES := {"satisfaction": "satisf.", "respect": "satisf.", "moral collectif": "moral", "moral": "moral",
	"confiance de direction": "conf.", "confiance": "conf.", "lien": "lien", "condition du leader": "cond. leader", "condition": "cond."}
## Réponse → [icône, couleur, mot court].
const REPONSES := {
	"ecouter": ["heart", Pastilles.BLEU], "rassurer": ["shield", Pastilles.VERT], "clarifier": ["info", Pastilles.TURQUOISE],
	"cadrer": ["flag", Pastilles.ORANGE], "responsabiliser": ["star", Pastilles.VIOLET],
	"mediation": ["people", Pastilles.TURQUOISE], "mentorat": ["star", Pastilles.VIOLET]}

## Effets d'un texte du moteur (« Satisfaction +1 ; premier entretien : moral +1. », « Dialogue encadré : lien +25,
## confiance de direction −1. ») en pastilles ▲ / ▼ qui passent à la ligne si la place manque.
static func effets(detail: String, taille: int = 16) -> HFlowContainer:
	var flux := HFlowContainer.new()
	flux.add_theme_constant_override("h_separation", C.px(6))
	flux.add_theme_constant_override("v_separation", C.px(6))
	flux.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var expression := RegEx.create_from_string("([A-Za-zÀ-ÿ' ]+?)\\s*([+\\-−])\\s*(\\d+)")
	var trouve_un := false
	var suivi := ""
	var texte := detail.strip_edges().rstrip(".").replace(",", ";")
	for morceau: String in texte.split(";", false):
		var partie := morceau.strip_edges()
		if ":" in partie: partie = partie.get_slice(":", partie.get_slice_count(":") - 1).strip_edges()
		var trouve := expression.search(partie)
		if trouve == null:
			suivi = partie
			continue
		trouve_un = true
		var positif := trouve.get_string(2) == "+"
		var libelle := trouve.get_string(1).strip_edges().to_lower()
		var court: String = LIBELLES.get(libelle, libelle)
		flux.add_child(Pastilles.pastille("%s %s%s %s" % ["▲" if positif else "▼", "+" if positif else "−", trouve.get_string(3), court], Pastilles.VERT if positif else Pastilles.ROUGE, "", detail, taille))
	if not trouve_un or not suivi.is_empty(): flux.add_child(Pastilles.pastille("", Pastilles.ORANGE, "clock", detail, taille))
	return flux

## Carte cliquable : contenu libre, survol et focus de la charte, toute la surface déclenche l'action.
static func carte(contenu: Control, action: Callable, id: String, bulle: String, couleur: Color, actif: bool = true, choisi: bool = false) -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.name = id + "Carte"
	var fond := C.box(Charte.PANNEAU_2.lerp(couleur, .10), couleur if choisi else Color.TRANSPARENT, Charte.RAYON_CARTE, 12)
	if choisi: fond.set_border_width_all(2)
	cadre.add_theme_stylebox_override("panel", fond)
	cadre.add_child(contenu)
	Pastilles._ignorer(contenu)
	var bouton := Button.new()
	bouton.name = id
	bouton.flat = true
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.tooltip_text = bulle
	bouton.accessibility_name = bulle
	bouton.disabled = not actif or not action.is_valid()
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color.TRANSPARENT
	vide.set_expand_margin_all(C.px(12))
	vide.set_corner_radius_all(C.px(Charte.RAYON_CARTE))
	var survol := vide.duplicate() as StyleBoxFlat
	survol.bg_color = Color(Charte.IVOIRE, .08)
	var focus := vide.duplicate() as StyleBoxFlat
	focus.set_border_width_all(2)
	focus.border_color = Charte.IVOIRE
	for etat in ["normal", "disabled"]: bouton.add_theme_stylebox_override(etat, vide)
	for etat in ["hover", "pressed"]: bouton.add_theme_stylebox_override(etat, survol)
	bouton.add_theme_stylebox_override("focus", focus)
	if action.is_valid(): bouton.pressed.connect(action)
	cadre.add_child(bouton)
	if not actif: cadre.modulate = Color(1, 1, 1, .6)
	Pastilles._marquer(cadre)
	return cadre

## Rangée de tuiles de même largeur.
static func rangee(tuiles: Array, ecart: int = 10) -> HBoxContainer:
	var ligne := C.h(ecart)
	for tuile: Control in tuiles:
		tuile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tuile.size_flags_stretch_ratio = 1.0
		ligne.add_child(tuile)
	return ligne

## Ligne d'action : liseré coloré, icône, mot à gauche, pastilles à droite.
static func ligne_action(id_reponse: String, libelle: String, detail: String, action: Callable, id: String, actif: bool) -> PanelContainer:
	var style: Array = REPONSES.get(id_reponse, ["check", Pastilles.BLEU])
	var ligne := C.h(12)
	var lisere := ColorRect.new()
	lisere.color = style[1]
	lisere.custom_minimum_size = Vector2(C.px(5), C.px(40))
	ligne.add_child(lisere)
	var icone := C.icon(style[0], 28, style[1])
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(icone)
	var mot := C.label(libelle, 20, Charte.IVOIRE, true, 700)
	mot.custom_minimum_size.x = C.px(230)
	mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(mot)
	var flux := effets(detail, 15)
	flux.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flux.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(flux)
	var fleche := C.label("›", 26, Charte.IVOIRE_2, true, 700)
	fleche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(fleche)
	return carte(ligne, action, id, "%s · %s" % [libelle, detail], style[1], actif)

## Tuile de promesse : chrono, minutes, ▲ respect / ▼ non-respect.
static func tuile_promesse(minutes: int, action: Callable, id: String, actif: bool) -> PanelContainer:
	var colonne := C.v(6)
	var tete := C.h(8)
	tete.add_child(C.icon("clock", 30, Pastilles.TURQUOISE))
	var chiffre := C.label("%d min" % minutes, 30, Charte.IVOIRE, true, 800)
	tete.add_child(chiffre)
	colonne.add_child(tete)
	var pastilles := C.h(6)
	pastilles.add_child(Pastilles.pastille("▲ +8", Pastilles.VERT, "", "Promesse tenue : +8 satisfaction.", 15))
	pastilles.add_child(Pastilles.pastille("▼ −10", Pastilles.ROUGE, "", "Promesse rompue : −10 satisfaction.", 15))
	pastilles.add_child(Pastilles.pastille("3 m.", Pastilles.BLEU, "calendar", "Sur trois rencontres.", 15))
	colonne.add_child(pastilles)
	var tuile := carte(colonne, action, id, "Promettre %d minutes sur trois rencontres" % minutes, Pastilles.TURQUOISE, actif)
	tuile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tuile

## Pastilles de personnalité (trait + leadership) à la place de la phrase « Personnalité : … ».
static func personnalite(trait_nom: String, leadership: Variant, action: Callable = Callable(), id: String = "RelationshipPersonality") -> HFlowContainer:
	var flux := HFlowContainer.new()
	flux.name = id
	flux.add_theme_constant_override("h_separation", C.px(6))
	flux.add_theme_constant_override("v_separation", C.px(6))
	if not trait_nom.is_empty(): flux.add_child(Pastilles.pastille(trait_nom, Pastilles.VIOLET, "people", "Personnalité : " + trait_nom, 16, id + "Trait", action))
	if leadership is int or leadership is float: flux.add_child(Pastilles.pastille("Leadership %d" % int(leadership), Pastilles.BLEU, "star", "Leadership %d / 100" % int(leadership), 16, id + "Leadership", action))
	return flux

## ---- Anneau de jauge -------------------------------------------------------------------------

class Anneau extends Control:
	var valeur := 0.0
	var maximum := 100.0
	var couleur := Color.WHITE
	var epaisseur := 10.0
	func _draw() -> void:
		var rayon := minf(size.x, size.y) / 2.0 - epaisseur / 2.0
		var centre := size / 2.0
		draw_arc(centre, rayon, 0.0, TAU, 72, Color(couleur, .18), epaisseur, true)
		var part := clampf(valeur / maxf(1.0, maximum), 0.0, 1.0)
		if part > 0.0: draw_arc(centre, rayon, -PI / 2.0, -PI / 2.0 + TAU * part, 72, couleur, epaisseur, true)

## Anneau chiffré : chiffre au centre, « / 100 » dessous, légende avec icône sous l'anneau.
static func anneau(valeur: float, legende: String, icone: String, couleur: Color, diametre: int = 120, id: String = "", action: Callable = Callable()) -> Control:
	var colonne := C.v(6)
	var dessin := Anneau.new()
	dessin.valeur = valeur
	dessin.couleur = couleur
	dessin.epaisseur = C.px(diametre * .09)
	dessin.custom_minimum_size = Vector2(C.px(diametre), C.px(diametre))
	dessin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dessin.add_child(centre)
	var chiffres := C.v(0)
	var chiffre := C.label(str(int(valeur)), int(diametre * .3), Charte.IVOIRE, true, 800)
	chiffre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chiffres.add_child(chiffre)
	var sur := C.label("/ 100", maxi(12, int(diametre * .11)), Charte.IVOIRE_2, true, 600)
	sur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chiffres.add_child(sur)
	centre.add_child(chiffres)
	colonne.add_child(dessin)
	var bas := C.h(6)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_child(C.icon(icone, 18, couleur))
	bas.add_child(C.label(legende.to_upper(), 14, couleur, true, 700))
	colonne.add_child(bas)
	if not action.is_valid():
		colonne.name = id
		return colonne
	var tuile := carte(colonne, action, id, "%s %d / 100" % [legende, int(valeur)], couleur)
	tuile.add_theme_stylebox_override("panel", C.box(Color.TRANSPARENT, Color.TRANSPARENT, Charte.RAYON_CARTE, 6))
	return tuile

## Couleur d'une satisfaction : vert ≥ 70, orange ≥ 45, rouge sinon (toujours avec le chiffre).
static func teinte(valeur: Variant) -> Color:
	if not (valeur is int or valeur is float): return Charte.IVOIRE_2
	return Pastilles.VERT if valeur >= 70 else (Pastilles.ORANGE if valeur >= 45 else Pastilles.ROUGE)

## Portrait cliquable : visage, nom court, barre de satisfaction colorée, étoile du relais.
static func vignette(joueur: Dictionary, identite: Dictionary, choisi: bool, relais: bool, action: Callable) -> PanelContainer:
	var colonne := C.v(4)
	var visage := G.portrait(int(identite.get("portraitIndex", posmod(str(joueur.get("id", "")).hash(), 32))), C.px(84), identite)
	visage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if relais:
		var etoile := C.icon("star", 22, Charte.OR)
		etoile.position = Vector2(C.px(62), 0)
		visage.add_child(etoile)
	colonne.add_child(visage)
	var nom := str(identite.get("name", joueur.get("name", "")))
	var court := nom.get_slice(" ", nom.get_slice_count(" ") - 1) if " " in nom else nom
	var mot := C.label(court, 15, Charte.IVOIRE if choisi else Charte.IVOIRE_2, true, 700)
	mot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mot.custom_minimum_size.x = C.px(104)
	mot.clip_text = true
	mot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	colonne.add_child(mot)
	var score: Variant = joueur.get("score")
	var barre := ProgressBar.new()
	barre.show_percentage = false
	barre.max_value = 100
	barre.value = float(score) if score is int or score is float else 0.0
	barre.custom_minimum_size = Vector2(C.px(80), C.px(6))
	barre.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for cle in ["background", "fill"]:
		var style := C.box(Charte.FILET if cle == "background" else teinte(score), Color.TRANSPARENT, 3, 0)
		Charte.sans_ombre(style)
		barre.add_theme_stylebox_override(cle, style)
	colonne.add_child(barre)
	return carte(colonne, action, "RelationshipPortrait_" + str(joueur.get("id", "")), "%s · satisfaction %s" % [nom, str(int(score)) if score is int or score is float else "—"], Charte.IVOIRE if choisi else Charte.FILET, true, choisi)

## Petite fenêtre visuelle : tous les joueurs suivis en portraits ; un clic choisit et ferme. Échap, ✕ et clic à côté ferment.
static func fenetre_portraits(app: Control, joueurs: Array, identites: Dictionary, choisi: String, relais: String, choisir: Callable) -> void:
	var calque := Control.new()
	calque.name = "RelationshipPortraitsWindow"
	calque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	calque.mouse_filter = Control.MOUSE_FILTER_STOP
	app.add_child(calque)
	var fermer := func(): if is_instance_valid(calque): calque.queue_free()
	PetiteFenetre.enregistrer(calque, fermer)
	var voile := ColorRect.new()
	voile.color = Color(Charte.NUIT, .55)
	voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	voile.gui_input.connect(func(e: InputEvent): if e is InputEventMouseButton and e.pressed: fermer.call())
	calque.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calque.add_child(centre)
	var panneau := PanelContainer.new()
	panneau.add_theme_stylebox_override("panel", Charte.ombrer(C.box(Charte.PANNEAU, Color.TRANSPARENT, Charte.RAYON_PANNEAU, 18)))
	centre.add_child(panneau)
	var colonne := C.v(12)
	panneau.add_child(colonne)
	var tete := C.h(8)
	var titre := C.label("Le groupe", 24, Charte.IVOIRE, true, 700)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(titre)
	var croix := G.button("✕", fermer)
	croix.name = "RelationshipPortraitsClose"
	tete.add_child(croix)
	colonne.add_child(tete)
	var grille := GridContainer.new()
	grille.columns = 8
	grille.add_theme_constant_override("h_separation", C.px(8))
	grille.add_theme_constant_override("v_separation", C.px(8))
	colonne.add_child(grille)
	for joueur: Dictionary in joueurs:
		var id := str(joueur.get("id", ""))
		grille.add_child(vignette(joueur, identites.get(id, joueur), id == choisi, id == relais, func():
			fermer.call()
			choisir.call(id)))

## Ligne d'une personne et de ses pastilles (engagements, historique, duos) ; passe à la ligne si la place manque.
static func ligne_lien() -> HFlowContainer:
	var flux := HFlowContainer.new()
	flux.add_theme_constant_override("h_separation", C.px(8))
	flux.add_theme_constant_override("v_separation", C.px(6))
	return flux

## Réponse donnée, en pastille de sa couleur et de son icône (le titre de l'événement en infobulle).
static func pastille_choix(id_reponse: String, libelle: String, bulle: String = "") -> Control:
	var style: Array = REPONSES.get(id_reponse, ["check", Pastilles.BLEU])
	return Pastilles.pastille(libelle, style[1], style[0], bulle if not bulle.is_empty() else libelle, 15)

## Souvenir d'un échange : liseré, réponse en pastille, date, titre court de l'événement, satisfaction avant → après.
static func souvenir(id_reponse: String, libelle: String, titre: String, date: String, avant: Variant, apres: Variant) -> PanelContainer:
	var style: Array = REPONSES.get(id_reponse, ["check", Pastilles.BLEU])
	var cadre := PanelContainer.new()
	cadre.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_CARTE, 8))
	var ligne := C.h(10)
	cadre.add_child(ligne)
	var lisere := ColorRect.new()
	lisere.color = style[1]
	lisere.custom_minimum_size = Vector2(C.px(4), C.px(30))
	ligne.add_child(lisere)
	var choix := pastille_choix(id_reponse, libelle, titre)
	choix.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(choix)
	var quand := Pastilles.pastille(date, Charte.IVOIRE_2, "calendar", date, 15)
	quand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(quand)
	if not titre.is_empty():
		var mot := C.label(titre, 16, Charte.IVOIRE_2, false, 600)
		mot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mot.clip_text = true
		mot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		mot.tooltip_text = titre
		mot.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_child(mot)
	if (avant is int or avant is float) and (apres is int or apres is float):
		var ecart := int(apres) - int(avant)
		var couleur: Color = Pastilles.VERT if ecart > 0 else (Pastilles.ROUGE if ecart < 0 else Charte.IVOIRE_2)
		var signe := "▲ +" if ecart > 0 else ("▼ −" if ecart < 0 else "= ")
		var effet := Pastilles.pastille("%s%d satisf. · %d → %d" % [signe, absi(ecart), int(avant), int(apres)], couleur, "", "Satisfaction %d → %d" % [int(avant), int(apres)], 15)
		effet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ligne.add_child(effet)
	cadre.tooltip_text = "%s · %s%s" % [libelle, date, (" · " + titre) if not titre.is_empty() else ""]
	return cadre
