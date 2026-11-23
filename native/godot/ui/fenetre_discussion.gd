extends RefCounted
## Fenêtre de discussion commune (revue FM27 : idée 23 « discussion avec un joueur », reprise telle quelle par l'idée 24
## « discussion avec un agent »). Choix de Léo du 23/11/2026 : petite fenêtre ; à GAUCHE les données de l'interlocuteur
## (dessinées par l'appelant), à DROITE l'échelle d'attitude qui bouge, le fil de bulles et nos phrases. Un clic sur une
## phrase la dit tout de suite : aucun bouton Valider. Échap, ✕ et clic à côté ferment (fenetre_visuelle.gd).
##
## ouvrir(page, cfg) — cfg :
##   nom, titre, icone : nom du calque, titre et icône de la fenêtre ; fermeture : Callable à la fermeture ;
##   prefixe : préfixe des nœuds créés (« Discussion » par défaut ; les suites les retrouvent par leur nom) ;
##   gauche : Callable(fenetre: Control, zone: Rect2) qui dessine les données dans `zone` (coordonnées du gabarit) ;
##   echelle : {paliers: [[mot, couleur, icône], …], avant: int, apres: int} (palier courant plein, l'ancien estompé,
##     flèche de l'un à l'autre) ;
##   visage : Callable() -> Control, petit portrait des bulles de l'interlocuteur ;
##   fil : [{qui: "lui" | "moi" | "repere", texte, couleur, id, effet: Control (sous la bulle), controle: Control
##     (repère centré : date, état)}, …], du plus ancien au plus récent, sur autant de tours que voulu ; le fil défile
##     jusqu'au dernier message et prend toute la hauteur quand il n'y a plus de choix ;
##   choix : [{id, texte, icone, couleur, action: Callable, actif: bool, choisi: bool, bulle}, …] (trois au plus).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Fenetre = preload("res://ui/immersive08/fenetre_visuelle.gd")
const V = preload("res://ui/relationships_visuals.gd")

const LARGEUR := 1760.0
const HAUTEUR := 1000.0
## Zone des données (gauche) et colonne de la discussion (droite), en unités du gabarit (2248 × 1230).
const GAUCHE := Rect2(28, 84, 780, 888)
const DROITE := Rect2(828, 84, 904, 888)
const ECHELLE_H := 50.0
const FIL := Rect2(828, 168, 904, 540)
const CHOIX_Y := 724.0
const CHOIX_H := 72.0
const CHOIX_ECART := 12.0

static func ouvrir(page: Control, cfg: Dictionary) -> Panel:
	var prefixe := str(cfg.get("prefixe", "Discussion"))
	var f := Fenetre.ouvrir(page, str(cfg.nom), str(cfg.get("titre", "Discussion")), str(cfg.get("icone", "people")), LARGEUR, HAUTEUR, cfg.get("fermeture", Callable()))
	var fond_gauche := D.rect(f, GAUCHE, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	fond_gauche.name = prefixe + "Donnees"
	var gauche: Callable = cfg.get("gauche", Callable())
	if gauche.is_valid(): gauche.call(f, GAUCHE)
	if cfg.get("echelle") is Dictionary: _echelle(f, cfg.echelle, prefixe)
	# Sans phrase à dire (discussion conclue), le fil prend aussi la place des choix : tout l'échange reste lisible.
	var choix_l: Array = cfg.get("choix", [])
	var zone_fil := FIL if not choix_l.is_empty() else Rect2(FIL.position, Vector2(FIL.size.x, DROITE.end.y - FIL.position.y))
	_fil(f, cfg.get("fil", []), cfg.get("visage", Callable()), prefixe, zone_fil)
	var y := CHOIX_Y
	for choix: Dictionary in cfg.get("choix", []):
		var carte := _carte_choix(choix)
		f.add_child(carte)
		D.place(carte, Rect2(DROITE.position.x, y, DROITE.size.x, CHOIX_H))
		y += CHOIX_H + CHOIX_ECART
	return f

## Échelle d'attitude : une case par palier, le palier courant en plein ; l'ancien teinté et une flèche s'il a bougé.
static func _echelle(f: Control, e: Dictionary, prefixe: String) -> void:
	var paliers: Array = e.get("paliers", [])
	if paliers.is_empty(): return
	var avant := clampi(int(e.get("avant", 0)), 0, paliers.size() - 1)
	var apres := clampi(int(e.get("apres", avant)), 0, paliers.size() - 1)
	var echelle := Control.new()
	echelle.name = prefixe + "EchelleAttitude"
	echelle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(echelle)
	D.place(echelle, Rect2(DROITE.position.x, DROITE.position.y, DROITE.size.x, ECHELLE_H + 26))
	var ecart := 8.0
	var case_l := (DROITE.size.x - ecart * (paliers.size() - 1)) / float(paliers.size())
	for i in paliers.size():
		var a: Array = paliers[i]
		var actif := i == apres
		var ancien := i == avant and avant != apres
		var fond := D.rect(echelle, Rect2(i * (case_l + ecart), 0, case_l, ECHELLE_H), Color(a[1], .9 if actif else (.32 if ancien else .12)), Charte.RAYON_PETIT)
		fond.name = prefixe + "Palier%d" % i
		fond.tooltip_text = str(a[0])
		fond.mouse_filter = Control.MOUSE_FILTER_PASS
		var teinte: Color = Charte.ENCRE if actif else (a[1] if ancien else Color(a[1], .7))
		D.text(fond, case_l * .5, 33, str(a[0]), 19, teinte, 700, case_l - 8, HORIZONTAL_ALIGNMENT_CENTER)
	if avant != apres:
		var a0 := avant * (case_l + ecart) + case_l * .5
		var a1 := apres * (case_l + ecart) + case_l * .5
		var fleche := D.rect(echelle, Rect2(minf(a0, a1), ECHELLE_H + 10, absf(a1 - a0), 5), Charte.IVOIRE, 2)
		fleche.name = prefixe + "EchelleFleche"
		D.text(echelle, a1 + (6 if a1 > a0 else -26), ECHELLE_H + 22, "▶" if a1 > a0 else "◀", 18, Charte.IVOIRE, 800, 22)

## Fil de discussion : bulles de l'interlocuteur à gauche (avec son visage), les nôtres à droite, repères centrés.
static func _fil(f: Control, messages: Array, visage: Callable, prefixe: String, zone: Rect2 = FIL) -> void:
	var fond := D.rect(f, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	fond.name = prefixe + "Fil"
	var defile := ScrollContainer.new()
	defile.name = prefixe + "FilDefile"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	f.add_child(defile)
	D.place(defile, Rect2(zone.position.x + 18, zone.position.y + 16, zone.size.x - 36, zone.size.y - 32))
	var liste := C.v(14)
	liste.name = prefixe + "FilListe"
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defile.add_child(liste)
	for m: Dictionary in messages:
		liste.add_child(_message(m, visage))
	# Le dernier message reste visible : le fil descend tout en bas une fois mis en page.
	var barre := defile.get_v_scroll_bar()
	var descendre := func():
		if is_instance_valid(defile): defile.scroll_vertical = int(barre.max_value)
	barre.changed.connect(descendre)

static func _message(m: Dictionary, visage: Callable) -> Control:
	var qui := str(m.get("qui", "lui"))
	var ligne := C.h(12)
	ligne.name = str(m.get("id", "Message"))
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if qui == "repere":
		ligne.alignment = BoxContainer.ALIGNMENT_CENTER
		var c: Variant = m.get("controle")
		if c is Control: ligne.add_child(c)
		return ligne
	var moi := qui == "moi"
	if moi:
		var vide := Control.new()
		vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ligne.add_child(vide)
	elif visage.is_valid():
		var tete: Control = visage.call()
		tete.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ligne.add_child(tete)
	var colonne := C.v(6)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var couleur: Color = m.get("couleur", Charte.IVOIRE_2)
	var bulle := PanelContainer.new()
	bulle.name = str(m.get("id", "Message")) + "Bulle"
	bulle.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU_3.lerp(couleur, .30 if moi else .20), Color.TRANSPARENT, Charte.RAYON_CARTE, 14))
	bulle.size_flags_horizontal = Control.SIZE_SHRINK_END if moi else Control.SIZE_SHRINK_BEGIN
	var mot := C.label(str(m.get("texte", "")), 23, Charte.IVOIRE, false, 600)
	mot.name = str(m.get("id", "Message")) + "Texte"
	bulle.add_child(mot)
	colonne.add_child(bulle)
	var effet: Variant = m.get("effet")
	if effet is Control:
		effet.size_flags_horizontal = Control.SIZE_SHRINK_END if moi else Control.SIZE_SHRINK_BEGIN
		colonne.add_child(effet)
	ligne.add_child(colonne)
	return ligne

## Une phrase : icône et couleur du ton, texte court ; toute la carte la dit (clic = dit tout de suite).
static func _carte_choix(choix: Dictionary) -> PanelContainer:
	var couleur: Color = choix.get("couleur", Charte.IVOIRE_2)
	var tete := C.h(14)
	var icone := C.icon(str(choix.get("icone", "mail")), 28, couleur)
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(icone)
	var phrase := C.label(str(choix.get("texte", "")), 24, Charte.IVOIRE, false, 600)
	phrase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phrase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(phrase)
	var choisi := bool(choix.get("choisi", false))
	var carte := V.carte(tete, choix.get("action", Callable()), str(choix.get("id", "Choix")), str(choix.get("bulle", choix.get("texte", ""))), couleur, bool(choix.get("actif", true)), choisi)
	if not bool(choix.get("actif", true)) and not choisi: carte.modulate = Color(1, 1, 1, .4)
	return carte
