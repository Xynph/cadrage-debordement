extends SceneTree
## Photos de pack recadrées sur le visage dans les cases carrées (ui/recadrage_visage.gd) :
## photo en pied → carré tête et épaules ; portrait serré presque entier ; image sans sujet entière ;
## résultat gardé dans le profil ; visages composés du jeu de base non touchés.
const G = preload("res://ui/game_skin.gd")
const R = preload("res://ui/recadrage_visage.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)

const PEAU := Color8(224, 172, 140)

func ellipse(image: Image, centre: Vector2, rayon: Vector2, couleur: Color) -> void:
	for y in range(maxi(0, int(centre.y - rayon.y)), mini(image.get_height(), int(centre.y + rayon.y) + 1)):
		for x in range(maxi(0, int(centre.x - rayon.x)), mini(image.get_width(), int(centre.x + rayon.x) + 1)):
			if pow((x - centre.x) / rayon.x, 2) + pow((y - centre.y) / rayon.y, 2) <= 1.0: image.set_pixel(x, y, couleur)

## Joueur en pied sur fond transparent : tête (cheveux, visage), cou, maillot, bras, jambes.
func joueur_en_pied(w: int, h: int, fond: Color) -> Image:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(fond)
	var k := w / 200.0
	image.fill_rect(Rect2i(Vector2i(Vector2(55, 88) * k), Vector2i(Vector2(90, 120) * k)), Color8(30, 70, 160))
	image.fill_rect(Rect2i(Vector2i(Vector2(35, 95) * k), Vector2i(Vector2(20, 80) * k)), PEAU)
	image.fill_rect(Rect2i(Vector2i(Vector2(145, 95) * k), Vector2i(Vector2(20, 80) * k)), PEAU)
	image.fill_rect(Rect2i(Vector2i(Vector2(65, 208) * k), Vector2i(Vector2(70, 90) * k)), Color8(240, 240, 240))
	image.fill_rect(Rect2i(Vector2i(Vector2(92, 72) * k), Vector2i(Vector2(16, 18) * k)), PEAU)
	ellipse(image, Vector2(100, 46) * k, Vector2(19, 18) * k, Color8(40, 28, 20))
	ellipse(image, Vector2(100, 56) * k, Vector2(16, 20) * k, PEAU)
	return image

func run() -> void:
	var dossier := OS.get_environment("CD_GODOT_DATA_DIR")
	if dossier.is_empty():
		printerr("Profil temporaire CD_GODOT_DATA_DIR obligatoire.")
		quit(2)
		return
	check(R.chemin_cache() == dossier.path_join("recadrage-visages.json"), "Cache dans le profil du joueur")
	# 1. Photo en pied (fond transparent) : carré centré sur la tête, bien plus serré que la photo.
	var pied := joueur_en_pied(400, 600, Color(0, 0, 0, 0))
	var debut := Time.get_ticks_usec()
	var zone := R.detecter(pied)
	var ms := (Time.get_ticks_usec() - debut) / 1000.0
	var visage := Rect2(84.0 / 200, 36.0 / 300, 32.0 / 200, 40.0 / 300)
	check(zone.encloses(visage), "Photo en pied : le visage est dans le carré %s" % zone)
	check(zone.size.x < 0.75 and absf(zone.get_center().x - 0.5) < 0.03, "Photo en pied : buste centré sur la tête %s" % zone)
	var crane := 28.0 / 300
	check(crane - zone.position.y > zone.size.y * 0.04, "Photo en pied : de l'air au-dessus du crâne %s" % zone)
	var tete_y := (56.0 / 300 - zone.position.y) / zone.size.y
	check(tete_y > 0.15 and tete_y < 0.45, "Photo en pied : tête dans le tiers haut du cercle (%.2f)" % tete_y)
	check((zone.end.y - 88.0 / 300) / zone.size.y > 0.2, "Photo en pied : épaules et haut du torse visibles")
	check(is_equal_approx(zone.size.x * 400, zone.size.y * 600), "Photo en pied : la zone est carrée")
	check(zone.get_center().y < 0.3, "Photo en pied : carré en haut de l'image (tête), pas sur le corps")
	# 2. Même joueur sur fond gris uni (sans transparence).
	var gris := R.detecter(joueur_en_pied(200, 300, Color8(128, 128, 128)))
	check(gris.encloses(visage) and gris.size.x < 0.75, "Fond uni : même recadrage sur la tête %s" % gris)
	# 2b. Bras levé collé à la tête, main au-dessus du crâne : le cadre reste sur la tête, pas sur le bras.
	var leve := joueur_en_pied(200, 300, Color(0, 0, 0, 0))
	leve.fill_rect(Rect2i(116, 14, 12, 80), PEAU)
	ellipse(leve, Vector2(118, 10), Vector2(9, 9), PEAU)
	var z_leve := R.detecter(leve)
	check(z_leve.encloses(visage) and z_leve.size.x < 0.75, "Bras levé : buste sur la tête %s" % z_leve)
	check(absf(z_leve.get_center().x - 0.5) < 0.08 and z_leve.position.y < 36.0 / 300 and z_leve.get_center().y < 0.3, "Bras levé : cadre centré sur la tête, pas sur la main %s" % z_leve)
	# 2c. Affiche : fond rouge, nom en grosses lettres blanches à droite, joueur en demi-corps à gauche.
	var affiche := Image.create(240, 300, false, Image.FORMAT_RGBA8)
	affiche.fill(Color8(196, 50, 54))
	# Lettres blanches bordées de rose (anticrénelage sur le rouge), lignes reliées par leur liseré : texte couleur peau.
	for ligne in 4:
		affiche.fill_rect(Rect2i(128, 12 + ligne * 14, 84, 12), Color8(226, 168, 160))
		affiche.fill_rect(Rect2i(130, 14 + ligne * 14, 80, 8), Color8(250, 250, 250))
		for barre in 8: affiche.fill_rect(Rect2i(132 + barre * 10, 14 + ligne * 14, 2, 8), Color8(226, 168, 160))
	affiche.fill_rect(Rect2i(128, 12, 2, 54), Color8(226, 168, 160))
	affiche.fill_rect(Rect2i(20, 170, 170, 130), Color8(25, 25, 30))
	affiche.fill_rect(Rect2i(86, 140, 28, 34), PEAU)
	ellipse(affiche, Vector2(100, 78), Vector2(36, 34), Color8(40, 28, 20))
	ellipse(affiche, Vector2(100, 98), Vector2(30, 40), PEAU)
	var z_affiche := R.detecter(affiche)
	check(z_affiche.encloses(Rect2(70.0 / 240, 58.0 / 300, 60.0 / 240, 80.0 / 300)), "Affiche : le visage est dans le carré %s" % z_affiche)
	check(z_affiche.size.x < 0.95 and z_affiche.get_center().x < 0.48 and z_affiche.position.y < 0.15, "Affiche : cadre sur le joueur, pas sur le texte %s" % z_affiche)
	# 3. Portrait serré (visage déjà grand) : on garde presque toute l'image.
	var serre := Image.create(200, 200, false, Image.FORMAT_RGBA8)
	serre.fill(Color8(120, 120, 125))
	serre.fill_rect(Rect2i(30, 150, 140, 50), Color8(20, 30, 60))
	ellipse(serre, Vector2(100, 60), Vector2(48, 45), Color8(40, 28, 20))
	ellipse(serre, Vector2(100, 92), Vector2(42, 55), PEAU)
	var z_serre := R.detecter(serre)
	check(z_serre.size.x > 0.85, "Portrait serré : presque toute l'image reste visible %s" % z_serre)
	# 4. Image sans sujet (aplat) : photo entière, rien n'est rogné.
	var aplat := Image.create(30, 40, false, Image.FORMAT_RGBA8)
	aplat.fill(Color("c83c64"))
	check(R.detecter(aplat) == Rect2(0, 0, 1, 1), "Aplat sans sujet : image entière")
	# 5. Dans le jeu : portrait de pack recadré, résultat gardé dans le profil, puis relu.
	var chemin := dossier.path_join("recadrage-pied.png")
	check(pied.save_png(chemin) == OK, "Photo de pack écrite dans le profil de test")
	var rect := G.portrait(0, 90, {"name": "Joueur Pied", "portraitPath": chemin})
	check(rect.texture is AtlasTexture and (rect.texture as AtlasTexture).atlas == G.textures.get(chemin), "Case carrée : photo du pack recadrée, même photo décodée")
	var region := (rect.texture as AtlasTexture).region if rect.texture is AtlasTexture else Rect2()
	check(absf(region.size.x - region.size.y) <= 1.0 and region.size.x < 300, "Case carrée : région carrée en buste %s" % region)
	var autre := G.portrait(1, 40, {"name": "Joueur Pied", "portraitPath": chemin})
	check(autre.texture == rect.texture, "Texture recadrée partagée entre les vues")
	# Cercles à anneau (terrain de la Composition, Entraînement, avant-match) : même recadrage, sans second rognage.
	var anneau: Control = load("res://ui/contextual/training_visuels.gd").portrait_anneau({"name": "Joueur Pied", "portraitPath": chemin}, 80.0)
	var disque: Control = anneau.get_node("PortraitDisque")
	var dans_disque := disque.get_child(0) as TextureRect
	check(dans_disque != null and dans_disque.texture == rect.texture, "Cercle à anneau : même photo recadrée que les vignettes")
	check(dans_disque != null and dans_disque.position == Vector2.ZERO and dans_disque.size.is_equal_approx(disque.size), "Cercle à anneau : photo entière dans le disque, ni agrandie ni décalée")
	anneau.free()
	check(FileAccess.file_exists(R.chemin_cache()), "Recadrage gardé dans le profil")
	var garde: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(R.chemin_cache()))
	check(int(garde.get("version", 0)) == R.VERSION and garde.regions.size() == 1, "Cache du profil : une entrée par photo")
	check(not FileAccess.file_exists(chemin.get_base_dir().path_join(".recadrage")), "Rien n'est écrit à côté des photos du pack")
	var calcule: Rect2 = R.region(chemin, pied)
	R._regions.clear()
	R._charge = false
	var relu: Rect2 = R.region(chemin, Image.create(8, 8, false, Image.FORMAT_RGBA8))
	check(relu.position.distance_to(calcule.position) < 0.001 and relu.size.distance_to(calcule.size) < 0.001, "Relu depuis le profil (sans nouvelle analyse) : même recadrage %s / %s" % [relu, calcule])
	# 6. Jeu de base : visage composé, aucune photo de pack, aucun recadrage.
	var avant := G.portrait_textures.size()
	var compose := G.portrait(2, 60, {"id": "base:1", "name": "Joueur Base", "age": 24, "appearanceBankVersion": 2})
	check(compose.texture != null and G.portrait_textures.size() == avant, "Jeu de base : visage composé inchangé, rien à recadrer")
	for node: Node in [rect, autre, compose]: node.free()
	print("CD_RECADRAGE ", JSON.stringify({"pied": [snappedf(zone.position.x, 0.01), snappedf(zone.position.y, 0.01), snappedf(zone.size.x, 0.01)], "analyse_ms": snappedf(ms, 0.1)}))
	print("RECADRAGE VISAGE : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
