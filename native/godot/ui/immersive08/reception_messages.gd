extends RefCounted
## Planche FM27 n° 20 « Messages à réponse » (CD_VARIANTE_VISUELLE=A|B ; sans variable : Réception inchangée).
## Catégorie de chaque courrier en pastille de couleur franche (clic = filtre de la liste), non lus en gras avec un point
## de la couleur de la catégorie, et bande rouge « RÉPONSE REQUISE » au bas d'un courrier du club qui attend une décision.
## A : liste à deux lignes, cartes de réponse gardées dans le courrier, bande fine en pied (Déléguer / Annuler / Envoyer).
## B : liste en colonnes sur une ligne (façon Effectif), réponses rangées en lignes DANS la bande rouge.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const ClubMail = preload("res://ui/club_mail.gd")

## Couleur franche par catégorie (jetons de la charte) ; le mot et l'icône accompagnent toujours la couleur.
const COULEURS := {"Médical":Charte.PERTE, "Staff":Charte.INTENSIF, "Direction":Charte.CONFIANCE, "Recrutement":Charte.MORAL,
	"Formation":Charte.REPOS, "Compétitions":Charte.CONDITION, "Presse":Color("d4e35c"), "Sélections":Charte.CREME,
	"Calendrier":Charte.CONDITION, "Invitation":Charte.CONFIANCE, "Club":Charte.GRIS_VERT, "Météo":Color("8fc6e8")}
const ROUGE_BANDE := Color("d9634f")
const LIGNE_B := 58.0
const LIGNE_REPONSE_B := 50.0

static func variante() -> String:
	var v := OS.get_environment("CD_VARIANTE_VISUELLE").strip_edges().to_upper()
	return v if v in ["A", "B"] else ""

static func couleur(service: String) -> Color:
	return COULEURS.get(service, Charte.GRIS_VERT)

## Le courrier attend une décision du manager (courrier du club avec réponses).
static func attend(app: Control, message: Dictionary) -> bool:
	return message.has("club_mail") and ClubMail.awaiting(app.model, message.club_mail) and not (message.club_mail.get("reponses", []) as Array).is_empty()

## Pastille de catégorie : voile + icône + mot, de la couleur de la catégorie ; clic = filtre de la liste sur ce sujet.
static func pastille(parent: Control, rect: Rect2, service: String, icone: String, taille: int, action: Callable) -> Button:
	var teinte := couleur(service)
	var bouton := Button.new()
	bouton.name = "InboxCategoryPill"
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.tooltip_text = service
	for etat in ["normal", "hover", "pressed", "focus"]:
		var fond := C.box(Color(teinte, .36 if etat == "hover" else .24), Color.TRANSPARENT, Charte.RAYON_PETIT, 0)
		Charte.sans_ombre(fond)
		bouton.add_theme_stylebox_override(etat, fond)
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	D.place(bouton, rect)
	var pictogramme := C.icon(icone, C.px(taille), teinte)
	pictogramme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bouton.add_child(pictogramme)
	D.place(pictogramme, Rect2(8, (rect.size.y - taille) / 2.0, taille, taille))
	var mot := D.text(bouton, 14 + taille, rect.size.y / 2.0 + taille * .36, service.to_upper(), taille - 2, teinte, 700, rect.size.x - taille - 20)
	mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bouton

static func largeur_pastille(service: String, taille: int) -> float:
	return C.font(700).get_string_size(service.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, taille - 2).x + taille + 26.0

## Hauteur de la bande rouge en pied du courrier ouvert (0 sans variante ou sans décision attendue).
static func hauteur_bande(app: Control, message: Dictionary) -> float:
	if variante().is_empty() or not attend(app, message): return 0.0
	if variante() == "A": return 74.0
	var n := (message.club_mail.get("reponses", []) as Array).size()
	return 64.0 + n * (LIGNE_REPONSE_B + 6.0) + 70.0

## Bande « RÉPONSE REQUISE ». `envoyer(choix)` envoie la réponse ; `choisir(choix)` la sélectionne (B) ; `annuler`.
static func bande(card: Panel, app: Control, state: Dictionary, message: Dictionary, largeur: float, bas: float, echeance: String, envoyer: Callable, choisir: Callable, annuler: Callable, suivant: Callable) -> void:
	var h := hauteur_bande(app, message)
	var mail: Dictionary = message.club_mail
	var options: Array = mail.get("reponses", [])
	var choisi := str(state.reply_pick.get(str(mail.id), ""))
	var lettre := ""
	for i in options.size():
		if str(options[i].get("id", "")) == choisi and options[i].get("disponible", false): lettre = char(65 + i)
	var zone := Panel.new()
	zone.name = "InboxReplyBand"
	var fond := C.box(Color("3a1d1a"), Color.TRANSPARENT, 0, 0)
	Charte.sans_ombre(fond)
	zone.add_theme_stylebox_override("panel", fond)
	card.add_child(zone)
	D.place(zone, Rect2(0, bas - h, largeur, h))
	D.rect(zone, Rect2(0, 0, largeur, 4), ROUGE_BANDE, 0).name = "InboxReplyBandRule"
	# En-tête de la bande : ⚠ + RÉPONSE REQUISE (Anton) + échéance.
	var haut := 46.0 if variante() == "B" else h / 2.0 + 14.0
	var alerte := C.icon("warning", C.px(30), ROUGE_BANDE)
	zone.add_child(alerte)
	D.place(alerte, Rect2(40, haut - 26, 30, 30))
	var titre := D.text(zone, 82, haut, "RÉPONSE REQUISE", 28, Charte.CREME, 700, 320)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "InboxReplyBandTitle"
	if not echeance.is_empty():
		var x_e := 82.0 + Charte.TITRE_FICHE.get_string_size("RÉPONSE REQUISE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 22.0
		D.text(zone, x_e, haut - 2, echeance, 19, Color(ROUGE_BANDE, 1).lightened(.25), 700, 260).name = "InboxReplyBandDue"
	if variante() == "B": _lignes_b(zone, app, state, message, largeur, choisi, choisir)
	# Commandes : Déléguer (l'adjoint répond à ta place), Annuler le choix, Envoyer ; « suivant non lu » en icône.
	var y := h - 62.0 if variante() == "B" else (h - 48.0) / 2.0
	var x := largeur - 40.0
	var suite := D.button(zone, Rect2(x - 54, y, 54, 48), "", suivant, false, "arrow", true, app.accent, "InboxReplyBandNext")
	suite.tooltip_text = "Courrier suivant non lu"
	C.style_bouton_lien(suite, 19)
	x -= 54 + 14
	var envoi := D.button(zone, Rect2(x - 300, y, 300, 48), ("Envoyer la réponse " + lettre) if not lettre.is_empty() else "Choisis une réponse", envoyer.bind(choisi), false, "", false, app.accent, "InboxClubMailSend")
	envoi.disabled = lettre.is_empty() or app.waiting
	C.style_bouton_contour(envoi, 21)
	if not envoi.disabled:
		for etat in ["normal", "hover", "focus"]:
			var plein := C.box(Charte.CREME if etat != "hover" else Charte.CREME.darkened(.08), Color.TRANSPARENT, Charte.RAYON_PILULE, 18)
			plein.content_margin_top = 0
			plein.content_margin_bottom = 0
			Charte.sans_ombre(plein)
			envoi.add_theme_stylebox_override(etat, plein)
		for cle in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]: envoi.add_theme_color_override(cle, Charte.PANNEAU)
	envoi.alignment = HORIZONTAL_ALIGNMENT_CENTER
	x -= 300 + 14
	if not lettre.is_empty():
		var retour := D.button(zone, Rect2(x - 150, y, 150, 48), "Annuler", annuler, false, "", true, app.accent, "InboxClubMailCancel")
		C.style_bouton_lien(retour, 19)
		retour.alignment = HORIZONTAL_ALIGNMENT_CENTER
		x -= 150 + 14
	var delegue := _premiere_disponible(options)
	var deleguer := D.button(zone, Rect2(x - 260, y, 260, 48), "Déléguer à Gabi", envoyer.bind(delegue), false, "people", true, app.accent, "InboxClubMailDelegate")
	deleguer.disabled = delegue.is_empty() or app.waiting
	deleguer.tooltip_text = "Gabi répond à ta place"
	C.style_bouton_contour(deleguer, 19)
	deleguer.alignment = HORIZONTAL_ALIGNMENT_CENTER

static func _premiere_disponible(options: Array) -> String:
	for option: Dictionary in options:
		if option.get("disponible", false): return str(option.get("id", ""))
	return ""

## B : chaque réponse = une ligne (lettre, libellé, conséquences en chiffres colorés) ; clic = choisir.
static func _lignes_b(zone: Panel, app: Control, state: Dictionary, message: Dictionary, largeur: float, choisi: String, choisir: Callable) -> void:
	var Reception = load("res://ui/immersive08/reception_canvas.gd")
	var options: Array = message.club_mail.get("reponses", [])
	var y := 66.0
	for i in options.size():
		var option: Dictionary = options[i]
		var id := str(option.get("id", ""))
		var dispo: bool = option.get("disponible", false)
		var pris := id == choisi and dispo
		var ligne := C.button("", choisir.bind(id), false, app.accent)
		ligne.name = "InboxClubMailReply_" + id
		ligne.set_meta("option_id", id)
		ligne.custom_minimum_size = Vector2.ZERO
		for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
			var teinte := Color(Charte.CREME, .14) if pris else (Color(Charte.CREME, .07) if etat == "hover" else Color(0, 0, 0, .22))
			var s := C.box(teinte, Charte.CREME if pris else Color.TRANSPARENT, Charte.RAYON_PETIT, 0)
			Charte.sans_ombre(s)
			ligne.add_theme_stylebox_override(etat, s)
		ligne.disabled = app.waiting or not dispo
		ligne.tooltip_text = str(option.get("libelle", "")) + "\n" + str(option.get("effets", ""))
		zone.add_child(ligne)
		D.place(ligne, Rect2(40, y, largeur - 80, LIGNE_REPONSE_B))
		var rond := D.rect(ligne, Rect2(12, 9, 32, 32), Charte.CREME if pris else Color(Charte.CREME, .12), 16)
		D.text(rond, 16, 23, "✓" if pris else char(65 + i), 18, Charte.PANNEAU if pris else Charte.CREME, 700, 32, HORIZONTAL_ALIGNMENT_CENTER)
		var libelle := str(option.get("libelle", ""))
		D.text(ligne, 60, 33, libelle, 21, Charte.CREME if dispo else Charte.IVOIRE_3, 700, 560).name = "InboxReplyLabel"
		var x := 640.0
		var effets: Array = Reception.consequences(str(option.get("effets", "")))
		if not dispo: effets = [["×", str(option.get("raison", "Indisponible")), Charte.IVOIRE_3]] + effets
		for effet: Array in effets.slice(0, 4):
			var texte := "%s %s" % [effet[0], effet[1]]
			var w := minf(C.font(600).get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 24.0, largeur - 80 - x - 16)
			if w < 60: break
			var puce := D.rect(ligne, Rect2(x, 11, w, 28), Color(effet[2], .16), Charte.RAYON_PETIT)
			puce.name = "InboxReplyEffect"
			D.text(puce, 12, 20, texte, 17, effet[2], 600, w - 18)
			x += w + 10
		y += LIGNE_REPONSE_B + 6.0
