extends RefCounted
## Recadrage des photos de pack sur le visage, pour les cercles et vignettes carrées.
##
## Les photos d'un pack (photos en pied, demi-corps, portraits serrés) sont affichées telles
## quelles dans des cases carrées : sur une photo en pied, le visage devient minuscule.
## Ici, on cherche le visage sur une copie réduite de la photo (plaque de peau épaisse, haute et centrale :
## pas une main levée, un bras collé à la tête, des avant-bras croisés ni le texte ou le fond rouge d'une affiche ;
## largeur de tête lue sur la peau du visage et la silhouette) et on rend un portrait buste (tête dans le tiers haut, centrée). Sans visage
## trouvé : carré en haut au centre pour une photo en hauteur dont le sujet se détache, photo entière sinon.
## Rien n'est écrit dans le pack : le résultat (rectangle en fractions de l'image) est gardé en
## mémoire et dans le profil du joueur (`<profil>/recadrage-visages.json`, profil = CD_GODOT_DATA_DIR sinon
## le dossier de données du jeu, comme main.gd).
## Exemple : `RecadrageVisage.region(chemin, image)` → Rect2(0.31, 0.04, 0.38, 0.25).

const VERSION := 3
const CACHE_NAME := "recadrage-visages.json"
## Côté le plus long de la copie analysée (px) : de quoi voir un visage d'une dizaine de px sur une photo en pied.
const ANALYSE := 160
## Côté du carré en largeurs de tête : portrait « buste » (tête, épaules, haut du torse).
const BUSTE := 3.3
## Air laissé au-dessus du crâne, en fraction du côté : la tête tombe dans le tiers haut.
const AIR_CRANE := 0.09

static var _regions: Dictionary = {}
static var _charge := false

## Rectangle (fractions de la largeur et de la hauteur) à montrer dans une case carrée.
static func region(path: String, image: Image) -> Rect2:
	_charger()
	var cle := _cle(path)
	if _regions.has(cle):
		var r: Array = _regions[cle]
		return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var found := detecter(image)
	_regions[cle] = [snappedf(found.position.x, 0.0001), snappedf(found.position.y, 0.0001), snappedf(found.size.x, 0.0001), snappedf(found.size.y, 0.0001)]
	_sauver()
	return found

static func _cle(path: String) -> String:
	var taille := 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		taille = f.get_length()
		f.close()
	return "%d|%s|%d|%d" % [VERSION, path, taille, FileAccess.get_modified_time(path)]

static func chemin_cache() -> String:
	var profil := OS.get_environment("CD_GODOT_DATA_DIR")
	return (profil if not profil.is_empty() else OS.get_user_data_dir()).path_join(CACHE_NAME)

static func _charger() -> void:
	if _charge: return
	_charge = true
	var chemin := chemin_cache()
	if not FileAccess.file_exists(chemin): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if parsed is Dictionary and int(parsed.get("version", 0)) == VERSION and parsed.get("regions") is Dictionary:
		_regions = parsed.regions

static func _sauver() -> void:
	var f := FileAccess.open(chemin_cache(), FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"version": VERSION, "regions": _regions}))
	f.close()

## Analyse pure (sans cache) : rectangle carré en fractions de l'image.
static func detecter(source: Image) -> Rect2:
	if source == null or source.is_empty(): return Rect2(0, 0, 1, 1)
	var W := source.get_width()
	var H := source.get_height()
	var echelle := float(ANALYSE) / maxi(W, H)
	var w := maxi(1, roundi(W * echelle))
	var h := maxi(1, roundi(H * echelle))
	if w < 8 or h < 8: return Rect2(0, 0, 1, 1)
	var img := source.duplicate() as Image
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var px := img.get_data()
	var n := w * h
	# Fond : transparence si le bord est transparent, sinon couleur médiane du bord (haut et moitié haute des côtés).
	var bord: PackedInt32Array = []
	for x in w: bord.append(x)
	for y in h / 2:
		bord.append(y * w)
		bord.append(y * w + w - 1)
	var transparents := 0
	var rs: PackedInt32Array = []
	var gs: PackedInt32Array = []
	var bs: PackedInt32Array = []
	for i in bord:
		if px[i * 4 + 3] < 128: transparents += 1
		rs.append(px[i * 4]); gs.append(px[i * 4 + 1]); bs.append(px[i * 4 + 2])
	var alpha := transparents > bord.size() * 0.2
	rs.sort(); gs.sort(); bs.sort()
	var fr := rs[rs.size() / 2]
	var fv := gs[gs.size() / 2]
	var fb := bs[bs.size() / 2]
	var fg := PackedByteArray(); fg.resize(n)
	var peau := PackedByteArray(); peau.resize(n)
	for i in n:
		var r := px[i * 4]
		var g := px[i * 4 + 1]
		var b := px[i * 4 + 2]
		var devant := px[i * 4 + 3] >= 128 if alpha else absi(r - fr) + absi(g - fv) + absi(b - fb) > 60
		if not devant: continue
		fg[i] = 1
		var lum := 0.299 * r + 0.587 * g + 0.114 * b
		var cb := 128.0 - 0.168736 * r - 0.331264 * g + 0.5 * b
		var cr := 128.0 + 0.5 * r - 0.418688 * g - 0.081312 * b
		# Rouge franc (fond d'affiche, maillot) et bordeaux écartés : la peau garde du vert (g ≥ 0,3 r) et peu de bleu.
		if cb >= 77.0 and cb <= 127.0 and cr >= 135.0 and cr <= 175.0 and lum > 35.0 and r > g and r > b and g * 10 >= r * 3 and b * 20 <= g * 23: peau[i] = 1
	# Fermeture légère : un pixel du sujet entouré d'au moins 3 pixels de peau devient peau.
	var ferme := PackedByteArray(); ferme.resize(n)
	for y in h:
		for x in w:
			var i := y * w + x
			if peau[i] == 1:
				ferme[i] = 1
				continue
			if fg[i] == 0: continue
			var voisins := 0
			for yy in range(maxi(0, y - 1), mini(h, y + 2)):
				for xx in range(maxi(0, x - 1), mini(w, x + 2)):
					voisins += peau[yy * w + xx]
			if voisins >= 3: ferme[i] = 1
	peau = ferme
	# Épaisseur de la peau (distance « échiquier » au bord) : un visage est plus épais qu'un bras levé, une main
	# ou un trait de texte d'affiche.
	var epaisseur := PackedInt32Array(); epaisseur.resize(n)
	for y in h:
		for x in w:
			var i := y * w + x
			if peau[i] == 0: continue
			var m := 0
			if x > 0 and y > 0:
				m = mini(epaisseur[i - 1], mini(epaisseur[i - w], epaisseur[i - w - 1]))
				if x < w - 1: m = mini(m, epaisseur[i - w + 1])
			epaisseur[i] = m + 1
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			if peau[i] == 0: continue
			var m := 0
			if x < w - 1 and y < h - 1:
				m = mini(epaisseur[i + 1], mini(epaisseur[i + w], epaisseur[i + w + 1]))
				if x > 0: m = mini(m, epaisseur[i + w - 1])
			epaisseur[i] = mini(epaisseur[i], m + 1)
	# Plaques de peau : la plus épaisse et la plus haute (visage plutôt que main levée, avant-bras croisés ou texte).
	var etiquettes := PackedInt32Array(); etiquettes.resize(n); etiquettes.fill(-1)
	var aire_min := maxf(6.0, n * 0.004)
	var meilleure := -1
	var score_meilleur := 0.0
	# À score presque égal (±10 %), la plaque la plus haute : visage barbu plutôt que cou.
	var haut_choisi := h
	var coeur_depart := -1
	var epaisseur_visage := 0
	var pile := PackedInt32Array()
	var numero := 0
	var bande0 := roundi(w * 0.15)
	var bande1 := roundi(w * 0.85)
	for depart in n:
		if peau[depart] == 0 or etiquettes[depart] >= 0: continue
		etiquettes[depart] = numero
		pile.append(depart)
		var aire := 0
		var somme_x := 0
		var miny := h
		var plus_epais := 0
		var meilleur_point := 0.0
		var point := depart
		while not pile.is_empty():
			var i := pile[pile.size() - 1]
			pile.remove_at(pile.size() - 1)
			var cx := i % w
			var cy := i / w
			aire += 1; somme_x += cx
			miny = mini(miny, cy)
			# Point du visage : épais, haut et central, pris dans la bande centrale (un fond d'affiche ou une chemise éclairée
			# collés au visage ne le déportent pas).
			if cx >= bande0 and cx <= bande1 and epaisseur[i] >= 2:
				var valeur := pow(epaisseur[i], 0.75) * maxf(0.05, 1.0 - 1.25 * cy / h) * (1.0 - absf(cx - w / 2.0) / w)
				if valeur > meilleur_point or (valeur == meilleur_point and i < point):
					meilleur_point = valeur
					plus_epais = epaisseur[i]
					point = i
			for v: int in [i - 1 if cx > 0 else -1, i + 1 if cx < w - 1 else -1, i - w, i + w]:
				if v < 0 or v >= n or peau[v] == 0 or etiquettes[v] >= 0: continue
				etiquettes[v] = numero
				pile.append(v)
		var milieu := float(somme_x) / aire
		var score := meilleur_point
		if aire >= aire_min and plus_epais >= 2 and milieu >= 0.12 * w and milieu <= 0.88 * w and (score > score_meilleur * 1.1 or (score > score_meilleur * 0.9 and miny < haut_choisi)):
			meilleure = numero
			score_meilleur = score
			haut_choisi = miny
			coeur_depart = point
			epaisseur_visage = plus_epais
		numero += 1
	var haut_meilleure := h
	var x0m := w
	var x1m := 0
	if meilleure >= 0:
		# Visage seul : cœur épais autour du point le plus épais, regonflé de son épaisseur ; un bras collé au visage,
		# plus fin, reste dehors.
		var seuil := maxi(1, ceili(epaisseur_visage * 0.55))
		var coeur := PackedByteArray(); coeur.resize(n)
		coeur[coeur_depart] = 1
		pile.append(coeur_depart)
		while not pile.is_empty():
			var i := pile[pile.size() - 1]
			pile.remove_at(pile.size() - 1)
			var cx := i % w
			for v: int in [i - 1 if cx > 0 else -1, i + 1 if cx < w - 1 else -1, i - w, i + w]:
				if v < 0 or v >= n or coeur[v] == 1 or etiquettes[v] != meilleure or epaisseur[v] < seuil: continue
				coeur[v] = 1
				pile.append(v)
		var rayon := epaisseur_visage * 2 + 2
		var large := PackedByteArray(); large.resize(n)
		for y in h:
			for x in w:
				if coeur[y * w + x] == 0: continue
				for xx in range(maxi(0, x - rayon), mini(w, x + rayon + 1)): large[y * w + xx] = 1
		var visage := PackedByteArray(); visage.resize(n)
		for y in h:
			for x in w:
				var i := y * w + x
				if etiquettes[i] != meilleure: continue
				for yy in range(maxi(0, y - rayon), mini(h, y + rayon + 1)):
					if large[yy * w + x] == 1:
						visage[i] = 1
						break
				if visage[i] == 1:
					haut_meilleure = mini(haut_meilleure, y)
					x0m = mini(x0m, x)
					x1m = maxi(x1m, x)
				else:
					etiquettes[i] = -2
		# La suite ne lit plus que la peau du visage.
		peau = visage
	var cote := 0.0
	var centre := Vector2.ZERO
	if meilleure >= 0:
		# Axe du visage : le point le plus épais (joues) ; front = haut de la peau du visage dans cet axe.
		var cxi := coeur_depart % w
		# Front : on remonte l'axe du visage tant qu'il y a de la peau (petits trous permis : bouche, ombre du nez) ;
		# les cheveux arrêtent la montée, donc une main posée au-dessus de la tête ne compte pas.
		var y0 := coeur_depart / w
		var demi := maxi(1, epaisseur_visage)
		var trou := 0
		var y_axe := y0
		while y_axe > 0 and trou <= maxi(3, epaisseur_visage * 3 / 4):
			y_axe -= 1
			var trouve := false
			for x in range(maxi(0, cxi - demi), mini(w, cxi + demi + 1)):
				if peau[y_axe * w + x] == 1:
					trouve = true
					break
			if trouve:
				y0 = y_axe
				trou = 0
			else:
				trou += 1
		# Largeur de tête : d'après la peau des premières lignes du visage…
		var largeur_peau := 0
		for y in range(y0, mini(h, y0 + maxi(8, h / 12))):
			var gauche := -1
			var droite := -1
			for x in range(maxi(0, cxi - w / 4), mini(w, cxi + w / 4 + 1)):
				if peau[y * w + x] == 1:
					if gauche < 0: gauche = x
					droite = x
			if gauche >= 0: largeur_peau = maxi(largeur_peau, droite - gauche + 1)
		# … et d'après la silhouette au niveau du front (cheveux compris), si le fond s'en distingue.
		var yf := mini(h - 1, y0 + maxi(2, h / 50))
		var a := cxi
		var b := cxi
		var silhouette_ok := fg[yf * w + cxi] == 1
		if silhouette_ok:
			while a > 0 and fg[yf * w + a - 1] == 1: a -= 1
			while b < w - 1 and fg[yf * w + b + 1] == 1: b += 1
		var largeur := b - a + 1
		var centre_x := (a + b + 1) / 2.0
		if not silhouette_ok or largeur > 0.6 * w or largeur < largeur_peau or largeur > largeur_peau * 3.0:
			largeur = maxi(largeur_peau, largeur if silhouette_ok and largeur <= 0.6 * w and largeur <= largeur_peau * 3.0 else 0)
			centre_x = cxi + 0.5
			silhouette_ok = false
		# Visage à moitié dans l'ombre : la peau n'en montre qu'une moitié ; l'épaisseur donne un minimum.
		largeur = maxi(largeur, maxi(3, roundi(epaisseur_visage * 2.4)))
		# Centre horizontal : médiane des milieux de la peau du visage (ligne par ligne, du front au bas du visage),
		# plus sûre que la silhouette quand les cheveux, un bras ou le fond la déportent.
		var milieux: Array[float] = []
		for y in range(y0, mini(h, y0 + maxi(2, roundi(largeur * 0.9)))):
			var c := cxi
			if peau[y * w + c] == 0:
				var trouve := -1
				for d in range(1, maxi(2, largeur / 3)):
					if c - d >= 0 and peau[y * w + c - d] == 1:
						trouve = c - d
						break
					if c + d < w and peau[y * w + c + d] == 1:
						trouve = c + d
						break
				if trouve < 0: continue
				c = trouve
			var g := c
			var dr := c
			while g > 0 and (peau[y * w + g - 1] == 1 or (g > 1 and peau[y * w + g - 2] == 1)): g -= 1
			while dr < w - 1 and (peau[y * w + dr + 1] == 1 or (dr < w - 2 and peau[y * w + dr + 2] == 1)): dr += 1
			# Ligne élargie par les épaules ou un bras : on s'arrête au cou.
			if dr - g + 1 > largeur * 1.3: break
			milieux.append((g + dr + 1) / 2.0)
		if milieux.size() >= 2:
			milieux.sort()
			var milieu_peau := milieux[milieux.size() / 2]
			# Silhouette et peau d'accord (écart < un quart de tête) : moyenne ; sinon la peau.
			centre_x = (centre_x + milieu_peau) / 2.0 if silhouette_ok and absf(centre_x - milieu_peau) < largeur * 0.25 else milieu_peau
		# Haut du crâne : on remonte la silhouette au-dessus du front, sinon ~ un tiers de tête de cheveux.
		var crane := float(y0) - largeur * 0.3
		if silhouette_ok:
			var yc := y0
			var xc := clampi(roundi(centre_x), 0, w - 1)
			while yc > 0 and fg[(yc - 1) * w + xc] == 1 and y0 - yc < largeur: yc -= 1
			# Jamais moins d'un quart de tête au-dessus du front (cheveux clairs ou fondus dans le fond).
			crane = minf(float(yc), y0 - largeur * 0.25)
		# Buste : tête (crâne → menton ≈ 1,35 largeur) dans le tiers haut, un peu d'air au-dessus du crâne.
		cote = largeur * BUSTE
		centre = Vector2(centre_x, crane - AIR_CRANE * cote + cote / 2.0)
		# « Visage » plus large que 40 % de la photo : chemise ou fond pris pour de la peau sous un éclairage chaud,
		# ou portrait déjà serré ; on fait comme sans visage.
		if largeur > 0.4 * w: meilleure = -1
	if meilleure < 0 and h > w * 1.15:
		# Pas de visage : carré en haut au centre (haut de la silhouette si elle se distingue).
		var haut := -1
		for y in h:
			var compte := 0
			for x in w: compte += fg[y * w + x]
			if compte >= maxi(2, roundi(w * 0.03)):
				haut = y
				break
		if haut < 0: return Rect2(0, 0, 1, 1)
		cote = w
		centre = Vector2(w / 2.0, maxf(0.0, haut - w * 0.04) + w / 2.0)
	elif meilleure < 0:
		return Rect2(0, 0, 1, 1)
	cote = clampf(cote, mini(w, h) * 0.25, mini(w, h))
	var coin := Vector2(clampf(centre.x - cote / 2.0, 0.0, w - cote), clampf(centre.y - cote / 2.0, 0.0, h - cote))
	# Carré exact dans la photo d'origine (l'arrondi de la copie réduite déforme d'un pixel).
	var cote_source := minf(cote / echelle, mini(W, H))
	var x := clampf(coin.x / w * W, 0.0, W - cote_source)
	var y := clampf(coin.y / h * H, 0.0, H - cote_source)
	return Rect2(x / W, y / H, cote_source / W, cote_source / H)
