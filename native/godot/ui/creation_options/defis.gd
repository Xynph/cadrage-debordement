extends RefCounted
## Écran de création · « Défis de départ » : bandeau de cartes en tête du choix du club. Les défis sont calculés
## par le moteur sur la vraie base (commande en lecture seule `start_challenges`, native/engine/defis-depart.cjs) ;
## une carte choisit son club (pays, division, sélection) et le défi, que la création transmet au moteur
## (`challenge`) pour fixer l'objectif du président et l'objectif chiffré du conseil.
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/carnet_skin.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const Kit = preload("res://ui/creation_options/kit.gd")
const CACHE := "creation_defis"
const DEMANDE := "creation_defis_demande"
const CHOIX := "creation_challenge"
const SELECTION := "creation_selection"
const ETAPE := "creation_step"

## Défis reçus du moteur (gardés en mémoire : le modèle suivant ne les porte plus).
static func liste(app: Control) -> Array:
	var vivant: Variant = app.model.get("meta", {}).get("startChallenges")
	if vivant is Array: app.management_ui[CACHE] = (vivant as Array).duplicate(true)
	var garde: Variant = app.management_ui.get(CACHE, [])
	return garde if garde is Array else []

## Une seule demande par session de création, après la construction de la page (la réponse la reconstruit).
static func demander(app: Control) -> void:
	if not liste(app).is_empty() or app.management_ui.get(DEMANDE, false): return
	var envoyer := func() -> void:
		if not is_instance_valid(app) or app.waiting or app.route != "Création" or app.management_ui.get(DEMANDE, false): return
		app.management_ui[DEMANDE] = true
		app.bridge.model_changed.connect(func(_model: Dictionary) -> void:
			if is_instance_valid(app) and app._has_career() and app.route == "Création": app.call_deferred("_render", false), CONNECT_ONE_SHOT)
		app._command("start_challenges", {})
	envoyer.call_deferred()

## Défi choisi pour ce club ({} sinon) : {id, titre, club, difficulte, niveau, objectif, rang, raison}.
static func choix(app: Control, club_id: int) -> Dictionary:
	var brut: Variant = app.management_ui.get(CHOIX, {})
	if not brut is Dictionary or int((brut as Dictionary).get("club", -1)) != club_id: return {}
	for defi: Dictionary in liste(app):
		if str(defi.get("id", "")) != str(brut.id): continue
		for offre: Dictionary in defi.get("clubs", []):
			if int(offre.get("club", -1)) == club_id:
				var resultat := offre.duplicate(true)
				resultat.id = defi.id
				resultat.titre = defi.titre
				return resultat
	return {}

## Charge utile de la création : {id, club} ou {} sans défi.
static func charge(app: Control, club_id: int) -> Dictionary:
	var d := choix(app, club_id)
	return {} if d.is_empty() else {"id": str(d.id), "club": club_id}

static func etoiles(n: int) -> String:
	return "★".repeat(clampi(n, 0, 5)) + "☆".repeat(5 - clampi(n, 0, 5))

## Choisit le défi et son club : la page de choix du club s'ouvre sur lui (pays, division, sélection).
static func choisir(app: Control, defi_id: String, club: Dictionary) -> void:
	var actuel: Variant = app.management_ui.get(CHOIX, {})
	if actuel is Dictionary and str(actuel.get("id", "")) == defi_id and int(actuel.get("club", -1)) == int(club.id):
		app.management_ui.erase(CHOIX)
		app._render()
		return
	app.management_ui[CHOIX] = {"id": defi_id, "club": int(club.id)}
	app.club_division = str(club.get("division", app.club_division))
	app.management_ui[SELECTION] = int(club.id)
	app.management_ui.erase(ETAPE)
	app._render()

static func _club(catalogue: Array, id: int) -> Dictionary:
	for club: Dictionary in catalogue:
		if int(club.get("id", -1)) == id: return club
	return {}

## Titre du défi avec le nom de la 3e division de la réalité active (« Fédérale » dans le jeu de base).
static func _titre(app: Control, defi: Dictionary) -> String:
	var titre := str(defi.get("titre", ""))
	if str(defi.get("id", "")) != "nationale" or not app.pack_manager.has_method("competition"): return titre
	var identite: Dictionary = app.pack_manager.competition("nationale", "creation")
	var nom := str(identite.get("shortName", identite.get("name", ""))).strip_edges()
	return titre if nom.is_empty() else titre.replace("Nationale", nom)

## Bandeau des défis (rien tant que le moteur n'a pas répondu, ou s'il n'en propose aucun).
static func build(app: Control, parent: Node, catalogue: Array) -> void:
	var defis := liste(app)
	demander(app)
	if defis.is_empty(): return
	var actuel: Variant = app.management_ui.get(CHOIX, {})
	var cadre := C.v(6)
	cadre.name = "CreationDefis"
	parent.add_child(cadre)
	var tete := C.h(12)
	cadre.add_child(tete)
	tete.add_child(Kit.caps("Défis de départ", 21))
	var aide := C.label("Une histoire toute prête : choisis-en une, ou prends le club de ton choix.", 20, C.MUTED, false)
	aide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tete.add_child(C.fill(aide))
	var rangee := C.h(10)
	rangee.name = "CreationDefisCartes"
	cadre.add_child(rangee)
	for defi: Dictionary in defis:
		var offres: Array = (defi.get("clubs", []) as Array).filter(func(o: Dictionary) -> bool: return not _club(catalogue, int(o.club)).is_empty())
		if offres.is_empty(): continue
		var choisi := -1
		if actuel is Dictionary and str(actuel.get("id", "")) == str(defi.id): choisi = int(actuel.get("club", -1))
		var principal: Dictionary = offres[0]
		for offre: Dictionary in offres:
			if int(offre.club) == choisi: principal = offre
		var club := _club(catalogue, int(principal.club))
		var carte := Button.new()
		carte.name = "CreationDefi_" + str(defi.id)
		carte.focus_mode = Control.FOCUS_ALL
		carte.disabled = app.waiting
		carte.custom_minimum_size.y = C.px(150)
		carte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		carte.tooltip_text = "%s\n%s\n%s" % [_titre(app, defi), defi.accroche, principal.raison]
		var actif := choisi == int(principal.club)
		var fond := C.box(Color("1d3328") if actif else Kit.SURFACE, Editorial.RAIL_GOLD if actif else Editorial.LINE, 6, 10)
		fond.border_width_left = maxi(2, C.px(4)) if actif else 1
		for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := fond.duplicate() as StyleBoxFlat
			if etat == "hover": style.border_color = Editorial.RAIL_GOLD
			carte.add_theme_stylebox_override(etat, style)
		carte.pressed.connect(choisir.bind(app, str(defi.id), club))
		rangee.add_child(carte)
		var contenu := C.v(2)
		contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.add_child(contenu)
		contenu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, C.px(10))
		var titre := C.label(_titre(app, defi), 25, Editorial.RAIL_GOLD, true, 700)
		titre.clip_text = true
		contenu.add_child(titre)
		var nom := C.label(G.club_name(club), 28, C.IVORY, true, 700)
		nom.clip_text = true
		contenu.add_child(nom)
		var ligne := C.label("%s  %s · %s" % [etoiles(int(principal.difficulte)), principal.niveau, principal.objectif], 20, C.MUTED, false)
		ligne.clip_text = true
		contenu.add_child(ligne)
		# Autres clubs du même défi : un clic les propose à la place.
		if offres.size() > 1:
			var autres := C.h(6)
			contenu.add_child(autres)
			for offre: Dictionary in offres:
				if offre == principal: continue
				var autre := _club(catalogue, int(offre.club))
				var puce := Button.new()
				puce.name = "CreationDefiAutre_%s_%d" % [defi.id, int(offre.club)]
				puce.text = "%s %s" % [str(autre.get("abbr", G.club_name(autre))), etoiles(int(offre.difficulte)).replace("☆", "")]
				puce.tooltip_text = "%s · %s · %s" % [G.club_name(autre), offre.niveau, offre.raison]
				puce.flat = true
				puce.disabled = app.waiting
				puce.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
				puce.add_theme_color_override("font_color", C.MUTED)
				puce.add_theme_color_override("font_hover_color", C.IVORY)
				puce.pressed.connect(choisir.bind(app, str(defi.id), autre))
				autres.add_child(puce)
