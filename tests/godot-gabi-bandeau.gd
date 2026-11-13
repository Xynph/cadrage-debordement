extends SceneTree
## Gabi dans le bandeau du haut et chez lui au Bureau (choix de Léo, 13/11/2026 : option « A + C »), sur une
## vraie carrière Monde (moteur réel) :
## - Gabi présent dans le bandeau des écrans principaux (visage, remarque), sans recouvrir aucun texte ni
##   bouton ; un clic ouvre sa bulle (avis + menu), qui descend du bandeau et se ferme d'un clic ailleurs ;
## - zone de Gabi au Bureau sans chevauchement avec les blocs, qui restent lisibles (plus de bouton
##   « Préparer la suite du club » sur « Tout le calendrier ») ;
## - mise en page revenue à 100 % (plus de bande basse réservée ni de médaillon dans le coin) ;
## - Gabi coupé : bandeau vide, Bureau classique ; réactivé : il revient.
const ContextualFlow = preload("helpers/contextual_flow.gd")
const C = preload("res://ui/immersive08/components.gd")
const ROUTES := ["Réception", "Bureau", "Effectif", "Composition", "Préparation", "Recrutement", "Club", "Finances", "Classements", "Formation"]
const OFFICE_CARDS := ["OfficeFixture", "OfficeDecisions", "OfficeGroup", "OfficeStandings", "OfficeJournal", "OfficeRecruitment", "OfficeTimeline", "OfficeRecentResults"]
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)

func wait_model() -> void:
	var until := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Moteur réel disponible")

func settle() -> void:
	await create_timer(.3).timeout
	for i in 10: await process_frame

func capture(id: String) -> void:
	var directory := OS.get_environment("CD_GABI_CAPTURES")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(id + ".png"))

func inside(node: Node, ancestor: Node) -> bool:
	while node != null:
		if node == ancestor: return true
		node = node.get_parent()
	return false

## Rectangle peint d'un contrôle (texte resserré pour un libellé), coupé par ses ancêtres qui découpent.
func painted(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	if control is Label:
		var label: Label = control
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var font: Font = label.get_theme_font("font")
			var px: int = label.get_theme_font_size("font_size")
			var scale := control.get_global_transform().get_scale().x
			var width := minf(rect.size.x, font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x * scale)
			var left := rect.position.x
			if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER: left += (rect.size.x - width) / 2.0
			elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT: left = rect.end.x - width
			rect = Rect2(left, rect.position.y, width, minf(rect.size.y, font.get_height(px) * scale * 1.2))
	var ancestor: Node = control.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents: rect = rect.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return rect

## Textes, boutons et icônes visibles de l'écran, hors du sous-arbre `except`.
func content(except: Array) -> Array:
	var result: Array = []
	for node in app.root_content.find_children("*", "Control", true, false):
		var control: Control = node
		if not control.is_visible_in_tree() or control.modulate.a < .05: continue
		if except.any(func(other: Node) -> bool: return inside(control, other)): continue
		var keep := false
		if control is Label: keep = not (control as Label).text.strip_edges().is_empty()
		elif control is BaseButton: keep = true
		elif control is TextureRect: keep = control.size.x * control.get_global_transform().get_scale().x <= 64.0
		if not keep: continue
		var rect := painted(control)
		if rect.has_area(): result.append([control, rect])
	return result

func run() -> void:
	root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app); await wait_model(); app.timer.stop()
	app._command("new_career", {"club": 0, "mode": "world-champ"}); await wait_model()
	await ContextualFlow.settle_club_meetings(app, self, check)
	check(str(app.model.meta.get("mode")) == "world", "Carrière Monde")
	var coach: Control = app.coach
	app._navigate("Bureau"); await settle()
	if coach.expanded: coach.close(); await settle()
	await layout_normal()
	for route: String in ROUTES:
		if coach.expanded: coach.close()
		app._navigate(route); await settle()
		if coach.expanded: coach.close(); await settle()
		coach.fermer_bulle(); await settle()
		await bandeau(route)
	await bulle()
	await bureau()
	await coupe()
	print("GABI_BANDEAU ", checks, " controles, ", failures.size(), " echec", "s" if failures.size() > 1 else "")
	quit(1 if failures.size() > 0 else 0)

## Plus de bande basse ni de médaillon : la mise en page reprend sa taille d'avant #684.
func layout_normal() -> void:
	var layout: Control = app.root_content.get_node("ImmersiveLayout")
	var reference := Vector2(2560, 1440) * C.density
	var factor := minf(app.root_content.size.x / reference.x, app.root_content.size.y / reference.y)
	var footer_px := C.px(44)
	if footer_px * factor < 38.0 and app.root_content.size.y > 38.0:
		factor = minf(factor, (app.root_content.size.y - 38.0) / (reference.y - footer_px))
	check(absf(layout.scale.y - factor) < 0.0005, "Mise en page à 100 %% : échelle %.4f (attendu %.4f, sans bande basse)" % [layout.scale.y, factor])
	check(layout.scale.y >= 0.99, "Mise en page non réduite en 1080p (%.4f)" % layout.scale.y)
	var footer: Control = app.root_content.find_child("ImmersiveFooter", true, false)
	check(footer != null and footer.custom_minimum_size.y <= maxf(C.px(44), 38.0 / layout.scale.y) + 0.5, "Pied de page sans bande réservée")
	check(app.root_content.find_child("CoachCompactDock", true, false) == null, "Plus de dock de Gabi dans le pied de page")
	check(app.find_child("GabiAvis", true, false) == null, "Plus de bouton « Ton avis, Gabi ? » dans le pied de page")
	var shell: GDScript = load("res://ui/immersive08/shell.gd")
	check(not shell.get_script_constant_map().has("GABI_BAND"), "Plus de réserve de coin (GABI_BAND)")

func bandeau(route: String) -> void:
	var coach: Control = app.coach
	var zone: Control = app.root_content.find_child("GabiBandeau", true, false)
	var topbar: Control = app.root_content.find_child("ImmersiveTopbar", true, false)
	check(zone != null and zone.is_visible_in_tree(), "Gabi dans le bandeau : " + route)
	if zone == null or topbar == null: return
	var band := zone.get_global_rect()
	check(topbar.get_global_rect().grow(1).encloses(band), "Zone de Gabi dans le bandeau du haut : " + route)
	check(band.size.x >= 250.0, "Zone de Gabi assez large (%d px) : %s" % [band.size.x, route])
	var face: Control = zone.find_child("GabiMedaillon", true, false)
	check(face != null and face.is_visible_in_tree() and band.grow(1).encloses(face.get_global_rect()), "Visage de Gabi dans le bandeau : " + route)
	var image: TextureRect = zone.find_child("GabiVisageImage", true, false)
	check(image != null and image.texture != null, "Visage de Gabi rendu (texture du portrait) : " + route)
	var remark: Label = zone.find_child("GabiRemarque", true, false)
	check(remark != null and not remark.text.strip_edges().is_empty(), "Remarque du moment : " + route)
	check(coach._adjoint_actif(), "Gabi actif dans le bandeau : " + route)
	var covered: Array = []
	for item: Array in content([zone, coach]):
		if (item[1] as Rect2).intersects(band): covered.append(str((item[0] as Node).name) + ":" + str((item[0] as Control).get("text") if (item[0] as Control).get("text") != null else ""))
	check(covered.is_empty(), "Gabi ne recouvre aucun texte ni bouton du bandeau ou de l'écran : %s %s" % [route, covered])
	var search: Control = topbar.find_child("ImmersiveSearch", true, false)
	var date: Control = topbar.find_child("ImmersiveCalendarDate", true, false)
	check(search != null and search.is_visible_in_tree() and not search.get_global_rect().intersects(band), "Recherche lisible, à côté de Gabi : " + route)
	check(date != null and date.is_visible_in_tree() and not date.get_global_rect().intersects(band) and date.get_global_rect().position.x > band.end.x, "Date lisible, à droite de Gabi : " + route)
	check(app.header_date != null and not str(app.header_date.text).is_empty(), "Date affichée : " + route)
	await capture("bandeau-" + route.to_lower())

## Clic sur Gabi : bulle d'avis (« Ton avis, Gabi ? » + menu), sous le bandeau ; fermée d'un clic ailleurs.
func bulle() -> void:
	var coach: Control = app.coach
	app._navigate("Effectif"); await settle()
	if coach.expanded: coach.close(); await settle()
	coach.fermer_bulle()
	coach._attente.clear()
	var zone: Control = app.root_content.find_child("GabiBandeau", true, false)
	if zone == null: return
	await click_at(zone.get_global_rect().get_center())
	var bubble: Control = coach._bulle
	check(bubble.visible, "Clic sur Gabi : sa bulle s'ouvre")
	check(str(coach._bulle_titre.text) == "TON AVIS, GABI ?", "La bulle donne son avis : " + str(coach._bulle_titre.text))
	check(not str(coach._bulle_texte.text).is_empty(), "Avis non vide")
	for id in ["GabiMenuAide", "GabiMenuVisite"]:
		check(bubble.find_child(id, true, false) != null, "Menu de la bulle : " + id)
	var topbar: Control = app.root_content.find_child("ImmersiveTopbar", true, false)
	check(bubble.get_global_rect().position.y >= topbar.get_global_rect().end.y - 1, "La bulle descend du bandeau (sous lui)")
	check(Rect2(Vector2.ZERO, app.size).grow(1).encloses(bubble.get_global_rect()), "Bulle entière dans l'application")
	await capture("bulle-effectif")
	# Un clic ailleurs ferme la bulle (sans être avalé).
	await click_at(Vector2(app.size.x * .45, app.size.y * .8))
	check(not bubble.visible, "Un clic ailleurs ferme la bulle")
	# Elle ne reste pas ouverte : fermeture d'elle-même après le temps de lecture.
	await click_at(zone.get_global_rect().get_center())
	check(bubble.visible, "Bulle rouverte")
	coach._bulle_reste = 0.05
	for i in 12: await process_frame
	check(not bubble.visible, "La bulle se ferme d'elle-même")
	# Le menu ouvre l'aide de l'écran en grand (mode grand conservé), et un second clic sur Gabi ferme la bulle.
	await click_at(zone.get_global_rect().get_center())
	await click_at(zone.get_global_rect().get_center())
	check(not bubble.visible, "Second clic sur Gabi : bulle refermée")
	# Limite de fréquence : une seule bulle spontanée par jour de jeu.
	coach._jour_spontane = ""
	check(coach._spontane_permis(), "Première bulle spontanée du jour permise")
	check(not coach._spontane_permis(), "Seconde bulle spontanée du même jour refusée (elle attend sous l'indice)")
	coach._attente = {"genre": "contexte", "titre": "GABI", "texte": "Un mot pour toi, coach.", "route": str(app.route), "categorie": "consigne", "ton": "neutre"}
	coach._maj_indice()
	await settle()
	var face: Control = zone.find_child("GabiMedaillon", true, false)
	check(face != null and face.indice, "Indice discret quand Gabi a quelque chose à dire")
	check(str(coach._remarque) == "Un mot pour toi, coach.", "Le fil du bandeau donne le message en attente")
	await click_at(zone.get_global_rect().get_center())
	check(bubble.visible and str(coach._bulle_texte.text) == "Un mot pour toi, coach.", "Clic : le message en attente s'ouvre")
	check(not face.indice, "Indice éteint une fois le message lu")
	coach.fermer_bulle()

func transparent(button: Button) -> bool:
	var style := button.get_theme_stylebox("normal") as StyleBoxFlat
	return style != null and style.bg_color.a < .05 and (style.border_color.a < .05 or style.get_border_width_min() == 0)

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		event.position = point; event.global_position = point
		root.push_input(event, true)
		await process_frame
	await settle()

## Bureau : la zone de Gabi est une vraie zone de l'écran, sans chevauchement, et les blocs restent lisibles.
func bureau() -> void:
	var coach: Control = app.coach
	app._navigate("Bureau"); await settle()
	if coach.expanded: coach.close(); await settle()
	coach.fermer_bulle(); await settle()
	var zone: Control = app.root_content.find_child("GabiBureau", true, false)
	check(zone != null and zone.is_visible_in_tree(), "Zone de Gabi au Bureau")
	if zone == null: return
	var rect := zone.get_global_rect()
	var body: Rect2 = app.body_scroll.get_global_rect()
	check(rect.position.x >= body.position.x - 1 and rect.end.x <= body.end.x + 1, "Zone de Gabi dans la largeur de l'écran")
	check(rect.size.y >= rect.size.x * 1.8, "Zone de Gabi en hauteur (Gabi debout en entier)")
	for id: String in OFFICE_CARDS:
		var card: Control = app.root_content.find_child(id, true, false)
		if card == null: continue
		check(not card.get_global_rect().intersects(rect), "Zone de Gabi sans chevauchement : " + id)
	var carnet: Control = zone.find_child("GabiCarnet", true, false)
	var figure: Control = zone.find_child("GabiBureauFigure", true, false)
	check(carnet != null and figure != null, "Carnet de la semaine et Gabi en pied")
	if carnet != null and figure != null:
		check(not carnet.get_global_rect().intersects(figure.get_global_rect()), "Gabi debout sous son carnet, sans chevauchement")
		check(rect.grow(1).encloses(carnet.get_global_rect()) and rect.grow(1).encloses(figure.get_global_rect()), "Carnet et figure dans la zone")
		check((figure as TextureRect).texture != null, "Gabi en pied rendu")
		check(figure.get_global_rect().size.y >= app.size.y * .3, "Gabi en grand (%d px de haut)" % figure.get_global_rect().size.y)
	for key in ["match", "groupe", "alerte", "conseil"]:
		var line: Label = zone.find_child("GabiLigne_" + key, true, false)
		check(line != null and not line.text.strip_edges().is_empty(), "Synthèse de la semaine : " + key)
		if line != null and carnet != null: check(carnet.get_global_rect().grow(1).encloses(line.get_global_rect()), "Ligne dans le carnet : " + key)
	var follow: Button = zone.find_child("GabiBureauSuivre", true, false)
	check(follow != null and follow.text == "Suivre le conseil", "Conseil avec action au Bureau")
	if is_instance_valid(coach._pied):
		check(coach._pied.visible, "Gabi en pied animé pendant l'affichage du Bureau")
	# Blocs du Bureau : aucun bouton n'en recouvre un autre ni un texte (correction de « Préparer la suite »).
	var planning: Control = app.root_content.find_child("OfficeManagerPlanning", true, false)
	var calendar: Control = app.root_content.find_child("OfficeCalendarAction", true, false)
	check(planning != null and calendar != null and not planning.get_global_rect().intersects(calendar.get_global_rect()), "« Préparer la suite du club » ne chevauche plus « Tout le calendrier »")
	for id: String in OFFICE_CARDS:
		var card: Control = app.root_content.find_child(id, true, false)
		if card == null: continue
		var buttons := card.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.is_visible_in_tree() and not b.text.strip_edges().is_empty())
		var labels := card.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.is_visible_in_tree() and not l.text.strip_edges().is_empty())
		for button: Button in buttons:
			for other: Button in buttons:
				if other != button and other.get_instance_id() > button.get_instance_id(): check(not button.get_global_rect().intersects(other.get_global_rect()), "Boutons distincts dans %s : %s / %s" % [id, button.text, other.text])
			for label: Label in labels:
				if inside(label, button): continue
				# Un texte peut frôler un bouton (quelques pixels de la boîte de ligne) : on refuse qu'il passe dessous.
				# Un bouton transparent (titre cliquable d'une priorité) ne masque pas le texte qui le touche.
				if transparent(button): continue
				var text_rect := painted(label)
				var shared := text_rect.intersection(button.get_global_rect()).get_area()
				check(shared <= text_rect.get_area() * 0.3, "Texte lisible dans %s : « %s » sous « %s »" % [id, label.text, button.text])
		var outside := card.get_global_rect().grow(2)
		for label: Label in labels:
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF: check(outside.encloses(painted(label)) or painted(label).size.x < 1, "Texte dans son bloc %s : %s" % [id, label.text])
	await capture("bureau")

## Réglage pour couper Gabi : bandeau vide, Bureau classique ; F1 (aide) le réactive.
func coupe() -> void:
	var coach: Control = app.coach
	app._navigate("Bureau"); await settle()
	coach.disable(); await settle(); await settle()
	var zone: Control = app.root_content.find_child("GabiBandeau", true, false)
	check(zone == null or not zone.is_visible_in_tree(), "Gabi coupé : plus de Gabi dans le bandeau")
	check(app.root_content.find_child("GabiBureau", true, false) == null, "Gabi coupé : Bureau classique")
	var fixture: Control = app.root_content.find_child("OfficeFixture", true, false)
	check(fixture != null and absf(fixture.size.x - 1360 * C.density) <= 1.5, "Gabi coupé : blocs du Bureau en pleine largeur")
	coach.open_help(); await settle(); await settle()
	coach.close(); await settle()
	zone = app.root_content.find_child("GabiBandeau", true, false)
	check(zone != null and zone.is_visible_in_tree(), "Gabi réactivé : de retour dans le bandeau")
	check(app.root_content.find_child("GabiBureau", true, false) != null, "Gabi réactivé : de retour au Bureau")
