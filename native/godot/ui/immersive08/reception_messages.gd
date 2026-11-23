extends RefCounted
## Messages à réponse (idée FM27 n° 20, choix de Léo du 23/11/2026 : A avec des réponses visuelles comme B).
## Catégorie de chaque courrier en pastille de couleur franche (clic = filtre de la liste), non lus en gras avec un point
## de la couleur de la catégorie, et bande rouge « RÉPONSE REQUISE » au bas d'un courrier du club qui attend une
## décision : une tuile par réponse propre au mail (pictogramme + couleur franche de sa famille, libellé, effets en
## chiffres colorés) plus « Déléguer » (Gabi répond à ta place). Un clic sur une tuile ENVOIE la réponse : aucun bouton
## de confirmation (règle de Léo du 23/11/2026). Une fois répondu, la bande dit la réponse donnée, par toi ou par Gabi.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const ClubMail = preload("res://ui/club_mail.gd")

## Couleur franche par catégorie (jetons de la charte) ; le mot et l'icône accompagnent toujours la couleur.
const COULEURS := {"Médical":Charte.PERTE, "Staff":Charte.INTENSIF, "Conseil":Charte.CONFIANCE, "Transferts":Charte.MORAL,
	"Formation":Charte.REPOS, "Compétitions":Charte.CONDITION, "Presse":Color("d4e35c"), "Sélections":Charte.CREME,
	"Calendrier":Charte.CONDITION, "Invitation":Charte.CONFIANCE, "Club":Charte.GRIS_VERT, "Météo":Color("8fc6e8")}
## Famille d'une réponse (moteur : club-mail.cjs, genre) -> [couleur franche, pictogramme] ; pictogramme "" = ✕ écrit.
const GENRES := {
	"ecran":[Color("5aa9e6"), "arrow"], "soin":[Charte.REPOS, "heart"], "effort":[Charte.INTENSIF, "train"],
	"jeu":[Charte.CONDITION, "tactic"], "promesse":[Color("f28fb1"), "star"], "direction":[Charte.CONFIANCE, "shield"],
	"competition":[Color("8fc6e8"), "trophy"], "argent":[Color("e8c547"), "money"], "presse":[Color("d4e35c"), "globe"],
	"groupe":[Charte.MORAL, "people"], "attente":[Color("b9a6e0"), "hourglass"], "refus":[Charte.PERTE, ""],
	"neutre":[Charte.GRIS_VERT, "check"]}
## Tuile « Déléguer » : Gabi, l'adjoint, en crème (couleur à part des familles de réponses).
const GABI := Charte.CREME
const ROUGE_BANDE := Color("d9634f")
## Tuiles « remplies » (retouche de Léo du 23/11) : libellé à la taille du corps du message, effets lisibles, grande icône.
const TUILE_H := 124.0
const TAILLE_TITRE := 24
const TAILLE_EFFET := 20
const CARRE := 76.0
const ICONE := 46
## Début du texte dans la tuile (après le carré de l'icône) et marge droite.
const TEXTE_X := 14.0 + CARRE + 16.0
const MARGE_D := 14.0
const GAP := 14.0
const FAITE_H := 100.0

static func couleur(service: String) -> Color:
	return COULEURS.get(service, Charte.GRIS_VERT)

static func genre(nom: String) -> Array:
	return GENRES.get(nom, GENRES.neutre)

## Le courrier attend une décision du manager (courrier du club avec réponses).
static func attend(app: Control, message: Dictionary) -> bool:
	return message.has("club_mail") and ClubMail.awaiting(app.model, message.club_mail) and not (message.club_mail.get("reponses", []) as Array).is_empty()

## Le courrier du club a reçu sa réponse (du manager ou de Gabi).
static func repondu(app: Control, message: Dictionary) -> bool:
	return message.has("club_mail") and not ClubMail.answer(app.model, message.club_mail).is_empty()

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

## Hauteur de la bande en pied du courrier ouvert : réponse requise (selon la tuile la plus haute), réponse donnée,
## ou 0.
static func hauteur_bande(app: Control, message: Dictionary) -> float:
	if attend(app, message): return 64.0 + _hauteur_tuiles(message) + 22.0
	if repondu(app, message): return FAITE_H
	return 0.0

## Bande en pied du courrier : « RÉPONSE REQUISE » et ses tuiles (`envoyer(id)` dès le clic ; « deleguer » pour
## Gabi), ou la réponse donnée. `suivant` : courrier suivant non lu. `requise` : la réponse est attendue (À FAIRE) ;
## sinon (routine, comme la météo) la bande reste sobre, sans rouge.
static func bande(card: Panel, app: Control, message: Dictionary, largeur: float, bas: float, echeance: String, requise: bool, envoyer: Callable, suivant: Callable) -> void:
	var h := hauteur_bande(app, message)
	if h <= 0.0: return
	var ouverte := attend(app, message)
	var zone := Panel.new()
	zone.name = "InboxReplyBand" if ouverte else "InboxReplyDone"
	var fond := C.box(Color("3a1d1a") if ouverte and requise else C.PANEL.darkened(.25), Color.TRANSPARENT, 0, 0)
	Charte.sans_ombre(fond)
	zone.add_theme_stylebox_override("panel", fond)
	card.add_child(zone)
	D.place(zone, Rect2(0, bas - h, largeur, h))
	var suite := D.button(zone, Rect2(largeur - 40 - 54, (38.0 if ouverte else h / 2.0) - 24, 54, 48), "", suivant, false, "arrow", true, app.accent, "InboxReplyBandNext")
	suite.tooltip_text = "Courrier suivant non lu"
	C.style_bouton_lien(suite, 19)
	if ouverte: _requise(zone, app, message, largeur, echeance, requise, envoyer)
	else: _faite(zone, app, message, largeur, h)

## Largeur d'une tuile : les réponses du mail et « Déléguer » se partagent la largeur de la bande.
static func _largeur_tuile(message: Dictionary, largeur: float = -1.0) -> float:
	if largeur < 0.0: largeur = load("res://ui/immersive08/reception_canvas.gd").DETAIL_WIDTH
	var n := (message.club_mail.get("reponses", []) as Array).size() + 1
	return (largeur - 80.0 - GAP * (n - 1)) / n

## Effets affichés sur la tuile d'une réponse : [symbole, texte, couleur] ; indisponible : la raison seule.
static func _effets(option: Dictionary) -> Array:
	if not option.get("disponible", false): return [["×", str(option.get("raison", "Indisponible")), C.FAINT]]
	# Sans effet chiffré : rien sous le libellé (pas de phrase « sans effet »).
	if str(option.get("effets", "")).strip_edges().is_empty(): return []
	var lignes: Array = load("res://ui/immersive08/reception_canvas.gd").consequences(str(option.get("effets", "")))
	return lignes.slice(0, 4)

## Lignes du contenu d'une tuile : [lignes du libellé, lignes de chaque effet…] (retour à la ligne, jamais d'ellipse).
static func _contenu(libelle: String, effets: Array, largeur: float) -> Array:
	var R = load("res://ui/immersive08/reception_canvas.gd")
	# Mêmes polices que les étiquettes : libellé en gras (C.font(700)), effets en texte courant (C.BODY) ; marge de 4.
	var result: Array = [R.wrapped_lines(libelle, TAILLE_TITRE, largeur - 4.0, C.font(700))]
	for effet: Array in effets: result.append(R.wrapped_lines("%s %s" % [effet[0], effet[1]], TAILLE_EFFET, largeur - 4.0, C.BODY))
	return result

## Hauteur d'une ligne (unités de mise en page) : celle de la police réelle, qui ne descend jamais sous 12 px (petite
## fenêtre : le texte grossit par rapport au gabarit).
static func _ligne_titre() -> float:
	return C.font(700).get_height(maxi(12, C.px(TAILLE_TITRE))) / C.density + 3.0

static func _ligne_effet() -> float:
	return C.BODY.get_height(maxi(12, C.px(TAILLE_EFFET))) / C.density + 2.0

static func _hauteur_contenu(lignes: Array) -> float:
	var total := _ligne_titre() * int(lignes[0])
	for i in range(1, lignes.size()): total += _ligne_effet() * int(lignes[i]) + 2.0
	return total + (6.0 if lignes.size() > 1 else 0.0)

## Hauteur commune des tuiles : la plus haute, jamais sous TUILE_H.
static func _hauteur_tuiles(message: Dictionary) -> float:
	var w := _largeur_tuile(message) - TEXTE_X - MARGE_D
	var h := TUILE_H
	for option: Dictionary in message.club_mail.get("reponses", []):
		h = maxf(h, _hauteur_contenu(_contenu(str(option.get("libelle", "")), _effets(option), w)) + 32.0)
	return h

## Réponse requise : ⚠ + RÉPONSE REQUISE (Anton) + échéance, puis une tuile par réponse et la tuile « Déléguer ».
static func _requise(zone: Panel, app: Control, message: Dictionary, largeur: float, echeance: String, requise: bool, envoyer: Callable) -> void:
	var accent := ROUGE_BANDE if requise else Charte.GRIS_VERT
	D.rect(zone, Rect2(0, 0, largeur, 4), accent, 0).name = "InboxReplyBandRule"
	var x_titre := 40.0
	if requise:
		var alerte := C.icon("warning", C.px(30), ROUGE_BANDE)
		zone.add_child(alerte)
		D.place(alerte, Rect2(40, 16, 30, 30))
		x_titre = 82.0
	var legende := "RÉPONSE REQUISE" if requise else "TA RÉPONSE"
	var titre := D.text(zone, x_titre, 42, legende, 28, Charte.CREME, 700, 320)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "InboxReplyBandTitle"
	if not echeance.is_empty():
		var x_e := x_titre + Charte.TITRE_FICHE.get_string_size(legende, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 22.0
		D.text(zone, x_e, 40, echeance, 19, accent.lightened(.25), 700, 300).name = "InboxReplyBandDue"
	var mail: Dictionary = message.club_mail
	var options: Array = mail.get("reponses", [])
	var adjoint: Variant = mail.get("adjoint")
	var w := _largeur_tuile(message, largeur)
	var h := _hauteur_tuiles(message)
	var x := 40.0
	for option: Dictionary in options:
		var famille := genre(str(option.get("genre", "neutre")))
		var dispo: bool = option.get("disponible", false)
		var id := str(option.get("id", ""))
		var tuile := _tuile(zone, app, Rect2(x, 64, w, h), "InboxClubMailReply_" + id, str(option.get("libelle", "")), famille[0], famille[1], _effets(option), dispo, envoyer.bind(id))
		tuile.set_meta("option_id", id)
		tuile.set_meta("genre", str(option.get("genre", "neutre")))
		var detail := str(option.get("effets", ""))
		tuile.tooltip_text = str(option.get("libelle", "")) + ("\n" + detail if not detail.is_empty() else "") + ("" if dispo else "\n" + str(option.get("raison", "")))
		x += w + GAP
	var sans_gabi := [] if adjoint is String else [["×", "Ta décision", C.FAINT]]
	var gabi := _tuile(zone, app, Rect2(x, 64, w, h), "InboxClubMailDelegate", "Déléguer à Gabi", GABI, "people", sans_gabi, adjoint is String, envoyer.bind(ClubMail.DELEGUER))
	gabi.tooltip_text = "Gabi répond à ta place" if adjoint is String else "Gabi te laisse décider"

## Tuile de réponse : carré de couleur franche avec le pictogramme, libellé entier, effets en couleurs (un par ligne).
static func _tuile(zone: Panel, app: Control, rect: Rect2, nom: String, libelle: String, teinte: Color, icone: String, effets: Array, actif: bool, action: Callable) -> Button:
	var tuile := Button.new()
	tuile.name = nom
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var voile := .08 if etat == "disabled" else .32 if etat in ["hover", "pressed"] else .18
		var s := C.box(Color(teinte if etat != "disabled" else Charte.GRIS_VERT, voile), teinte if etat in ["hover", "focus"] else Color.TRANSPARENT, Charte.RAYON_PETIT, 0)
		Charte.sans_ombre(s)
		tuile.add_theme_stylebox_override(etat, s)
	tuile.disabled = not actif or app.waiting
	tuile.pressed.connect(action)
	tuile.accessibility_name = libelle
	zone.add_child(tuile)
	D.place(tuile, rect)
	var encre := teinte if actif else Color(Charte.GRIS_VERT, .5)
	var carre := D.rect(tuile, Rect2(14, (rect.size.y - CARRE) / 2.0, CARRE, CARRE), encre, Charte.RAYON_PETIT)
	carre.name = "InboxReplyIcon"
	carre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icone.is_empty():
		D.text(carre, CARRE / 2.0, CARRE * .72, "✕", ICONE, Charte.ENCRE, 800, CARRE, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		var picto := C.icon(icone, C.px(ICONE), Charte.ENCRE)
		carre.add_child(picto)
		D.place(picto, Rect2((CARRE - ICONE) / 2.0, (CARRE - ICONE) / 2.0, ICONE, ICONE))
	# Libellé et effets entiers (retour à la ligne, jamais d'ellipse), centrés dans la hauteur de la tuile.
	var largeur := rect.size.x - TEXTE_X - MARGE_D
	var lignes := _contenu(libelle, effets, largeur)
	var y := maxf(8.0, (rect.size.y - _hauteur_contenu(lignes)) / 2.0)
	var titre := C.wrap(libelle, TAILLE_TITRE, Charte.CREME if actif else Charte.IVOIRE_3, true, 700)
	titre.name = "InboxReplyLabel"
	titre.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	titre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tuile.add_child(titre)
	D.place(titre, Rect2(TEXTE_X, y, largeur, _ligne_titre() * int(lignes[0]) + 2))
	y += _ligne_titre() * int(lignes[0]) + 6.0
	# Effets en chiffres colorés (▲ favorable, ▼ défavorable, = neutre), un par ligne.
	for i in effets.size():
		var effet: Array = effets[i]
		var etiquette := C.wrap("%s %s" % [effet[0], effet[1]], TAILLE_EFFET, effet[2] if actif or effet[0] == "×" else C.FAINT, false, 600)
		etiquette.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tuile.add_child(etiquette)
		etiquette.name = "InboxReplyEffect" # après add_child : InboxReplyEffect, InboxReplyEffect2…
		D.place(etiquette, Rect2(TEXTE_X, y, largeur, _ligne_effet() * int(lignes[i + 1]) + 2))
		y += _ligne_effet() * int(lignes[i + 1]) + 2.0
	return tuile

## Réponse donnée : carré de la famille de la réponse, « TA RÉPONSE » ou « GABI A RÉPONDU », libellé.
static func _faite(zone: Panel, app: Control, message: Dictionary, largeur: float, h: float) -> void:
	var mail: Dictionary = message.club_mail
	var choix := ClubMail.chosen_option(app.model, mail)
	var famille := genre(str(choix.get("genre", "neutre")))
	var gabi := ClubMail.delegated(app.model, mail)
	D.rect(zone, Rect2(0, 0, largeur, 4), famille[0], 0).name = "InboxReplyDoneRule"
	var carre := D.rect(zone, Rect2(40, (h - 64) / 2.0, 64, 64), famille[0], Charte.RAYON_PETIT)
	carre.name = "InboxReplyIcon"
	if str(famille[1]).is_empty(): D.text(carre, 32, 47, "✕", 38, Charte.ENCRE, 800, 64, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var picto := C.icon(famille[1], C.px(38), Charte.ENCRE)
		carre.add_child(picto)
		D.place(picto, Rect2(13, 13, 38, 38))
	var qui := D.text(zone, 124, h / 2.0 - 10, "GABI A RÉPONDU" if gabi else "TA RÉPONSE", 17, GABI if gabi else C.MUTED, 700, 320)
	qui.name = "InboxReplyDoneWho"
	if gabi:
		var badge := C.icon("people", C.px(20), GABI)
		zone.add_child(badge)
		D.place(badge, Rect2(124 + C.font(700).get_string_size("GABI A RÉPONDU", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 10, h / 2.0 - 28, 20, 20))
	D.text(zone, 124, h / 2.0 + 24, str(choix.get("libelle", "")), 24, Charte.CREME, 700, largeur - 124 - 120).name = "InboxReplyDoneLabel"
