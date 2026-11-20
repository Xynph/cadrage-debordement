extends RefCounted
## Sous-pages du Staff (décision de Léo du 19/11/2026 : jamais de petite fenêtre, un clic change d'écran) : « Contrat du staff »
## (recruter ou prolonger), « Mentorat des jeunes », « Un mentor, un jeune » et « Engagements du staff ». Chacune garde la coque, un
## retour « ← Retour au staff » (Échap) et une étape d'historique Précédent / Suivant (`management_ui.club_page`, voir
## navigation_controller.gd). Le contenu vient des mêmes constructeurs que les anciennes fenêtres (staff_career_view.gd) : mêmes
## commandes, rien de dupliqué ; seules les fenêtres disparaissent.
## Exemple : `Pages.ouvrir(app, "contrat", {"staff_id": id, "renew": true})`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Legacy = preload("res://ui/immersive08/legacy_style.gd")
const Habillage = preload("res://ui/immersive08/recruitment_pages.gd")
const PAGES := ["contrat", "mentorat", "mentor", "engagements"]
const TITRES := {"contrat": "Contrat du staff", "mentorat": "Mentorat des jeunes", "mentor": "Un mentor, un jeune", "engagements": "Engagements du staff"}
const LARGEUR := 1560.0
const TOP := 132.0

static func actuelle(app: Control) -> String:
	var etat: Variant = app.management_ui.get("club_page")
	if not etat is Dictionary: return ""
	var page := str(etat.get("kind", ""))
	return page if page in PAGES else ""

static func etat(app: Control) -> Dictionary:
	var valeur: Variant = app.management_ui.get("club_page")
	return valeur if valeur is Dictionary else {}

static func ouvrir(app: Control, page: String, args: Dictionary = {}) -> void:
	if page not in PAGES: return
	var contenu := {"kind": page}
	contenu.merge(args)
	app.management_ui.club_page = contenu
	app._navigate("Staff", true, true)
	var cible := app.root_content.find_child("ClubRetour", true, false) as Control
	if cible != null: cible.grab_focus.call_deferred()

static func fermer(app: Control) -> void:
	app.management_ui.erase("club_page")
	app._navigate("Staff", true, true)

## « ← Retour » : « Un mentor, un jeune » revient au mentorat, le reste au staff.
static func retour(app: Control) -> void:
	if actuelle(app) == "mentor": ouvrir(app, "mentorat")
	else: fermer(app)

static func cle(courant: Dictionary) -> String:
	var kind := str(courant.get("kind", ""))
	if kind == "contrat": return "contrat|%s|%s" % [str(courant.get("staff_id", "")), "1" if courant.get("renew", false) else "0"]
	return kind

static func depuis_cle(valeur: String) -> Dictionary:
	if not valeur.begins_with("contrat|"): return {"kind": valeur}
	var morceaux := valeur.split("|")
	return {"kind": "contrat", "staff_id": morceaux[1] if morceaux.size() > 1 else "", "renew": morceaux.size() > 2 and morceaux[2] == "1"}

## Page entière sous les onglets du Club : retour, titre, contenu.
static func build(app: Control, canvas: Control) -> void:
	var courant := etat(app)
	var kind := actuelle(app)
	var lien := Kit.lien(canvas, Rect2(0, TOP + 8, 0, 38), "← Retour au mentorat" if kind == "mentor" else "← Retour au staff", func(): retour(app), "ClubRetour", 20)
	lien.tooltip_text = ""
	Kit.touche(canvas, lien.size.x / C.density + 10, TOP + 38, "Échap")
	var titre := Kit.titre(canvas, 0, TOP + 100, str(TITRES.get(kind, "")), 38, 1400)
	titre.name = "ClubSubpageTitle"
	D.line(canvas, Vector2(0, TOP + 124), Vector2(2248, TOP + 124), Charte.FILET)
	var cadre := D.rect(canvas, Rect2(0, TOP + 148, LARGEUR, 900), Charte.PANNEAU, 0)
	cadre.name = "ClubSubpage_" + kind
	cadre.mouse_filter = Control.MOUSE_FILTER_PASS
	cadre.clip_contents = true
	var defilement := ScrollContainer.new()
	defilement.name = "ClubSubpageScroll"
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cadre.add_child(defilement)
	D.place(defilement, Rect2(24, 18, LARGEUR - 48, 864))
	var liste := VBoxContainer.new()
	liste.add_theme_constant_override("separation", C.px(12))
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(liste)
	var Carriere: Variant = load("res://ui/staff_career_view.gd")
	var vie: Dictionary = app.model.get("clubLife", {})
	var fermer_page := func(): fermer(app)
	match kind:
		"contrat":
			var StaffView: Variant = load("res://ui/staff_view.gd")
			var personne: Dictionary = StaffView.person_by_id(app.model, str(courant.get("staff_id", "")))
			if personne.is_empty(): liste.add_child(C.wrap("Ce membre du staff n’est plus disponible.", 20, Charte.IVOIRE_2))
			else: Carriere.contrat_page(app, liste, personne, vie.get("staffCareer", {}), bool(courant.get("renew", false)), fermer_page)
		"mentorat": Carriere.mentorat_page(app, liste, vie.get("staffMentoring", {}), fermer_page)
		"mentor": Carriere.mentor_page(app, liste, vie.get("staffMentoring", {}), func(): ouvrir(app, "mentorat"))
		"engagements": Carriere.engagements_page(app, liste, vie.get("staffEmployment", {}))
	Legacy.apply(defilement, app.accent)
	Habillage._charte(defilement)
	var suivre := func(ajout: Node):
		if is_instance_valid(defilement) and defilement.is_ancestor_of(ajout): Habillage._teindre.call_deferred(ajout)
	var arbre := Engine.get_main_loop() as SceneTree
	arbre.node_added.connect(suivre)
	defilement.tree_exiting.connect(func():
		if arbre.node_added.is_connected(suivre): arbre.node_added.disconnect(suivre))
