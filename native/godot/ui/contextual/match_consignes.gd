extends RefCounted
## Consignes en direct et pilotage du match (moteur : dist/match-pilotage.js, projection `live.pilotage`,
## seulement dans le match du manager en carrière Monde) : cinq axes à trois crans, le cran du milieu neutre.
## Un clic envoie `set_consignes {axe, valeur}` tout de suite, sans pause : le moteur l'accepte à toute minute
## d'un match non terminé. Un seul widget pour le tableau de bord 2D (match_between.gd) et le tiroir Tactique
## du direct 3D (live_view.gd) : seuls les tailles et les couleurs (style) changent.
##
## Aussi : arbitre (rappel d'une ligne), bilans des consignes, journal du staff, état des joueurs après les
## causeries (libellé et sens : favorable, neutre, défavorable). L'écran n'invente rien : tout vient du moteur.
const W = preload("res://ui/contextual/match_tableau_widgets.gd")

const COMMANDE := "set_consignes"
## États favorables et défavorables (match-pilotage.js, PILOTAGE_ETATS) ; « indifferent » est neutre.
const ETATS_FAVORABLES := ["galvanise", "motive", "serein"]
const ETATS_DEFAVORABLES := ["tendu", "vexe", "relache"]

## Projection du pilotage du direct, ou {} (match hors carrière Monde, rencontre créée avant le pilotage).
static func pilotage(live: Dictionary) -> Dictionary:
	var valeur: Variant = live.get("pilotage")
	return valeur if valeur is Dictionary else {}

static func axes(p: Dictionary) -> Array:
	var valeur: Variant = p.get("axes")
	return valeur if valeur is Array else []

## Cran en place pour un axe : `consignes[axe]`, sinon `axes[].valeur`.
static func cran(p: Dictionary, axe: Dictionary) -> String:
	var consignes: Variant = p.get("consignes")
	var id := str(axe.get("id", ""))
	if consignes is Dictionary and (consignes as Dictionary).has(id): return str(consignes[id])
	return str(axe.get("valeur", ""))

## Charge utile de la commande.
static func charge(axe: String, valeur: String) -> Dictionary:
	return {"axe": axe, "valeur": valeur}

## Copie du pilotage où les crans envoyés et pas encore confirmés par le moteur (`envois` : axe → valeur)
## remplacent ceux du modèle : l'écran garde le choix du manager le temps de la réponse.
static func avec_envois(p: Dictionary, envois: Dictionary) -> Dictionary:
	if envois.is_empty() or p.is_empty(): return p
	var copie := p.duplicate()
	var consignes: Dictionary = (p.get("consignes") as Dictionary).duplicate() if p.get("consignes") is Dictionary else {}
	for axe: Variant in envois: consignes[str(axe)] = str(envois[axe])
	copie["consignes"] = consignes
	return copie

## Envois confirmés (le modèle porte la valeur envoyée) retirés de `envois`.
static func confirmer(p: Dictionary, envois: Dictionary) -> void:
	var consignes: Dictionary = p.get("consignes") if p.get("consignes") is Dictionary else {}
	for axe: Variant in envois.keys():
		if str(consignes.get(str(axe), "")) == str(envois[axe]): envois.erase(axe)

## Une ligne par axe : libellé, puis trois crans (le cran en place en or). Style : « taille » (police des
## crans), « taille_libelle », « hauteur » (d'un cran), « libelle » (largeur du libellé ; 0 : au-dessus des
## crans), « ecart », « rayon », « marge », « police » (Font ou null) et les couleurs « or », « texte »,
## « doux », « fond », « survol ». `envoyer` reçoit (axe, valeur) au clic sur un autre cran.
static func lignes(parent: Control, p: Dictionary, envoyer: Callable, style: Dictionary) -> Array[Button]:
	var boutons: Array[Button] = []
	for axe_v: Variant in axes(p):
		if axe_v is Dictionary: boutons.append_array(_ligne(parent, p, axe_v, envoyer, style))
	return boutons

static func _ligne(parent: Control, p: Dictionary, axe: Dictionary, envoyer: Callable, style: Dictionary) -> Array[Button]:
	var id := str(axe.get("id", ""))
	var largeur := int(style.get("libelle", 0))
	var ecart := int(style.get("ecart", 6))
	var ligne: BoxContainer
	if largeur > 0: ligne = HBoxContainer.new()
	else: ligne = VBoxContainer.new()
	ligne.name = "Consigne_" + id
	ligne.add_theme_constant_override("separation", ecart if largeur > 0 else maxi(1, roundi(ecart / 3.0)))
	parent.add_child(ligne)
	var libelle := Label.new()
	libelle.text = str(axe.get("label", id))
	libelle.tooltip_text = libelle.text
	libelle.mouse_filter = Control.MOUSE_FILTER_PASS
	libelle.add_theme_font_size_override("font_size", int(style.get("taille_libelle", style.get("taille", 14))))
	libelle.add_theme_color_override("font_color", style.get("doux", Color("aeb9b3")) as Color)
	var police: Variant = style.get("police")
	if police is Font: libelle.add_theme_font_override("font", police as Font)
	if largeur > 0:
		libelle.custom_minimum_size.x = largeur
		libelle.clip_text = true
		libelle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		libelle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		libelle.size_flags_vertical = Control.SIZE_FILL
	ligne.add_child(libelle)
	var crans := HBoxContainer.new()
	crans.name = "Consigne_%s_Crans" % id
	crans.add_theme_constant_override("separation", ecart)
	crans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(crans)
	var groupe := ButtonGroup.new()
	var actuel := cran(p, axe)
	crans.set_meta("cran", actuel)
	var boutons: Array[Button] = []
	var options: Array = axe.get("options", []) if axe.get("options") is Array else []
	for option_v: Variant in options:
		if not option_v is Dictionary: continue
		var option: Dictionary = option_v
		var valeur := str(option.get("id", ""))
		var bouton := _cran(str(option.get("label", valeur)), valeur == actuel, groupe, style)
		bouton.name = "Consigne_%s_%s" % [id, valeur]
		bouton.set_meta("axe", id)
		bouton.set_meta("valeur", valeur)
		bouton.pressed.connect(func() -> void: _choisir(crans, id, valeur, envoyer))
		crans.add_child(bouton)
		boutons.append(bouton)
	return boutons

## Clic sur un cran : le bouton s'allume tout de suite (groupe), la commande part si le cran change.
static func _choisir(crans: Control, axe: String, valeur: String, envoyer: Callable) -> void:
	if str(crans.get_meta("cran", "")) == valeur: return
	crans.set_meta("cran", valeur)
	envoyer.call(axe, valeur)

static func _cran(texte: String, choisi: bool, groupe: ButtonGroup, style: Dictionary) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.tooltip_text = texte
	bouton.toggle_mode = true
	bouton.button_group = groupe
	bouton.button_pressed = choisi
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton.size_flags_stretch_ratio = 1.0
	bouton.custom_minimum_size = Vector2(0, int(style.get("hauteur", 34)))
	bouton.add_theme_font_size_override("font_size", int(style.get("taille", 14)))
	var police: Variant = style.get("police")
	if police is Font: bouton.add_theme_font_override("font", police as Font)
	var rayon := int(style.get("rayon", 4))
	var marge := int(style.get("marge", 6))
	var or_: Color = style.get("or", W.OR)
	var fond: Color = style.get("fond", Color("18231f"))
	var survol: Color = style.get("survol", Color("1f2e2b"))
	var reglages := {"normal": [fond, Color.TRANSPARENT], "hover": [survol, Color.TRANSPARENT], "pressed": [Color(or_, 0.18), or_],
		"hover_pressed": [Color(or_, 0.24), or_], "disabled": [fond.darkened(0.2), Color.TRANSPARENT], "focus": [Color.TRANSPARENT, or_]}
	for etat: String in reglages:
		var couleurs: Array = reglages[etat]
		var boite := StyleBoxFlat.new()
		boite.bg_color = couleurs[0]
		boite.set_corner_radius_all(rayon)
		boite.content_margin_left = marge
		boite.content_margin_right = marge
		boite.content_margin_top = maxi(1, roundi(marge / 3.0))
		boite.content_margin_bottom = maxi(1, roundi(marge / 3.0))
		var bord: Color = couleurs[1]
		if bord.a > 0.0: boite.set_border_width_all(maxi(1, roundi(rayon / 4.0)))
		boite.border_color = bord
		bouton.add_theme_stylebox_override(etat, boite)
	var texte_couleur: Color = style.get("texte", W.IVOIRE)
	bouton.add_theme_color_override("font_color", style.get("doux", Color("aeb9b3")) as Color)
	bouton.add_theme_color_override("font_hover_color", texte_couleur)
	bouton.add_theme_color_override("font_focus_color", texte_couleur)
	for cle: String in ["font_pressed_color", "font_hover_pressed_color"]: bouton.add_theme_color_override(cle, or_)
	return bouton

## Lignes de bilan (une par consigne active, la plus récente d'abord) puis le journal du staff (le plus
## récent d'abord) : [{texte, minute, staff}], au plus `maximum`.
static func notes(p: Dictionary, maximum: int) -> Array[Dictionary]:
	var resultat: Array[Dictionary] = []
	var bilans: Array = (p.get("bilans") as Array).duplicate() if p.get("bilans") is Array else []
	bilans = bilans.filter(func(b: Variant) -> bool: return b is Dictionary and not str(b.get("texte", "")).is_empty())
	bilans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("depuis", 0)) > int(b.get("depuis", 0)))
	for bilan: Dictionary in bilans: resultat.append({"texte": str(bilan.texte), "minute": int(bilan.get("depuis", 0)), "staff": false})
	var journal: Array = p.get("journal") if p.get("journal") is Array else []
	for k in range(journal.size() - 1, -1, -1):
		var entree: Variant = journal[k]
		if not entree is Dictionary or str(entree.get("texte", "")).is_empty(): continue
		resultat.append({"texte": "%d′ · %s" % [int(entree.get("minute", 0)), str(entree.texte)], "minute": int(entree.get("minute", 0)), "staff": true})
	if resultat.size() > maximum: resultat.resize(maxi(0, maximum))
	return resultat

## Rappel d'une ligne : « Arbitre : Nom · résumé » ("" sans arbitre).
static func arbitre_texte(arbitre: Variant) -> String:
	if not arbitre is Dictionary or str(arbitre.get("nom", "")).is_empty(): return ""
	var resume := str(arbitre.get("resume", "")).strip_edges()
	return "Arbitre : %s" % str(arbitre.nom) + (" · " + resume if not resume.is_empty() else "")

## Sens d'un état de joueur : 1 favorable, -1 défavorable, 0 neutre.
static func sens_etat(etat: String) -> int:
	if etat in ETATS_FAVORABLES: return 1
	if etat in ETATS_DEFAVORABLES: return -1
	return 0

## Couleur d'un sens (réaction de causerie, état) : vert favorable, rouge de l'alerte, `neutre` sinon.
static func teinte(sens: int, neutre: Color) -> Color:
	if sens > 0: return W.VERT
	if sens < 0: return W.ALERTE
	return neutre

## État d'un joueur après les causeries ({etat, label, ...}), ou {}.
static func etat_joueur(p: Dictionary, id: Variant) -> Dictionary:
	var joueurs: Variant = p.get("joueurs")
	if not joueurs is Dictionary: return {}
	var etat: Variant = (joueurs as Dictionary).get(str(id))
	return etat if etat is Dictionary and not str(etat.get("label", "")).is_empty() else {}
