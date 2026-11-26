extends RefCounted
## Après l'essai et coups de pied placés (19 novembre 2026, match filmé : une quinzaine de
## secondes d'image presque figée après chaque essai, transformation et pénalité mal cadrées).
##
## Présentation seulement : rien n'est décidé ici. Le moteur dit qui marque, où, et si le tir
## passe ; ce module donne les places et les trajectoires qui l'habillent :
##   - places de la transformation (loi 8) : l'équipe qui défend se replie derrière sa ligne de
##     but, sous ses poteaux ; l'équipe du buteur se tient derrière le ballon ;
##   - élan du buteur : quelques pas derrière le ballon, dans l'axe des poteaux ;
##   - vol d'un tir au but : le ballon passe la ligne de but au-dessus de la barre, puis retombe
##     dans l'en-but ;
##   - places autour du marqueur (partenaires qui le félicitent) et place de l'arbitre qui
##     accorde l'essai.
## Repère du moteur : x de 0 à 100 (lignes de but), y de 0 à 70 (touches). Repère de la vue :
## x - 50, z = y - 35 (match_view.gd `_world`).

## Transformation : le plan déduit du moteur place le buteur à 22 m de la ligne, dans l'axe du
## point d'essai, y borné à 5 m des touches (match-direct.cjs `transformation`).
const DISTANCE_TRANSFORMATION := 22.0
const MARQUE_Y_MIN := 5.0
const MARQUE_Y_MAX := 65.0
## Défense repliée : deux rangs dans l'en-but (m derrière la ligne), un joueur tous les
## LIGNE_ECART m ; la ligne glisse vers le côté du tir de LIGNE_VERS_MARQUE (part de l'écart).
const LIGNE_PROFONDEUR := [1.2, 2.8]
const LIGNE_ECART := 1.7
const LIGNE_VERS_MARQUE := 0.35
## Équipe du buteur : rangs à SOUTIEN_RECUL m derrière le ballon (vers le milieu du terrain, où elle
## renverra), puis tous les SOUTIEN_RANG m ; SOUTIEN_PAR_RANG joueurs par rang, SOUTIEN_ECART m entre
## eux, jamais dans le couloir de COULOIR m de part et d'autre de l'axe du tir (la caméra filme le
## buteur dans cet axe, personne ne le masque).
const SOUTIEN_RECUL := 24.0
const SOUTIEN_RANG := 3.5
const SOUTIEN_ECART := 4.0
const SOUTIEN_PAR_RANG := 5
const COULOIR := 3.5
## Jamais au ras d'une touche ni au-delà de l'en-but (m).
const BORD := 2.0
const EN_BUT := 4.5
## Élan du buteur : posé ELAN m derrière le ballon, il s'élance et s'arrête à FRAPPE m du ballon.
const ELAN := 2.6
const FRAPPE := 0.45
## Vol d'un tir au but : il passe la ligne de but à BARRE + AU_DESSUS m (barre à 3 m), retombe
## AU_DELA m plus loin ; durée à VITESSE_VOL m/s de moyenne, bornée par VOL (au plus 1,2 s : le
## ballon passe la ligne avant que la régie annonce le résultat, RESULTAT = 1 s après la frappe).
const BARRE := 3.0
const AU_DESSUS := 1.6
const AU_DELA := 6.0
const VITESSE_VOL := 26.0
const VOL := [0.6, 1.2]
const BALLON_AU_SOL := 0.13
## Charge des défenseurs (loi 8 : ils quittent leur ligne de but dès que le buteur s'élance) : chacun
## sort de son en-but vers le ballon, de CHARGE m (rangs étagés de CHARGE_ETAGE), jamais plus loin que
## CHARGE_PART de la distance au ballon (en courant droit vers lui, ils se resserrent sur l'axe du tir).
## Match filmé du 25/11 : défenseurs figés sur leur ligne et ballon manqué retombé parmi eux.
const CHARGE := 11.0
const CHARGE_ETAGE := [1.0, 0.87, 0.75]
const CHARGE_PART := 0.5
## Partenaires autour du marqueur : à AUTOUR m de lui, en éventail face au terrain.
const AUTOUR := 1.2
const ECARTS_AUTOUR := [0.0, 0.95, -0.95, 1.9, -1.9, 2.8]
## Arbitre qui accorde l'essai : à côté du point d'aplati, côté tribune lointaine (il ne masque
## pas le groupe), ARBITRE_ECART m sur le côté, un pas vers l'en-but.
const ARBITRE_ECART := 3.0


## Ligne de but que l'équipe `camp` attaque (le camp 0 attaque x = 100).
static func but_x(camp: int) -> float:
	return 100.0 if camp == 0 else 0.0


## Marque de la transformation d'un essai aplati en `essai_y` par `camp`.
static func marque(camp: int, essai_y: float) -> Vector2:
	var sens := 1.0 if camp == 0 else -1.0
	return Vector2(but_x(camp) - sens * DISTANCE_TRANSFORMATION, clampf(essai_y, MARQUE_Y_MIN, MARQUE_Y_MAX))


## Places de la transformation. `joueurs` : [{id, side, x, y}] (repère du moteur) ; `camp` : équipe
## du buteur ; `exclu` (le buteur) : laissé où il est (sa place est la marque). Rend id -> Vector2.
## Chacun prend la place libre la plus proche dans l'ordre des y : personne ne croise toute la ligne.
static func places(joueurs: Array, camp: int, marque_tir: Vector2, exclu: String = "") -> Dictionary:
	var resultat: Dictionary = {}
	if camp not in [0, 1]:
		return resultat
	var but := but_x(camp)
	var sens := 1.0 if camp == 0 else -1.0
	var defense: Array = []
	var attaque: Array = []
	for joueur: Variant in joueurs:
		if not joueur is Dictionary:
			continue
		var id := str(joueur.get("id", ""))
		if id.is_empty() or id == exclu:
			continue
		var y := float(joueur.get("y", 35.0))
		if int(joueur.get("side", -1)) == camp:
			attaque.append([y, id])
		elif int(joueur.get("side", -1)) == 1 - camp:
			defense.append([y, id])
	defense.sort()
	attaque.sort()
	# Défense : en-but, deux rangs alternés, centrée entre les poteaux et le côté du tir.
	var n := defense.size()
	var centre := clampf(lerpf(35.0, marque_tir.y, LIGNE_VERS_MARQUE), BORD + n * LIGNE_ECART * 0.5, 70.0 - BORD - n * LIGNE_ECART * 0.5) if n > 0 else 35.0
	for k in n:
		var y := clampf(centre + (k - (n - 1) * 0.5) * LIGNE_ECART, BORD, 70.0 - BORD)
		var profondeur: float = LIGNE_PROFONDEUR[k % 2]
		resultat[str(defense[k][1])] = Vector2(but + sens * profondeur, y)
	# Équipe du buteur : rangs derrière le ballon (plus loin de la ligne que lui), de part et d'autre
	# de l'axe du tir prolongé (poteaux -> marque), hors du couloir de la caméra.
	var m := attaque.size()
	var rangs := ceili(float(m) / SOUTIEN_PAR_RANG)
	var places_attaque: Array = []
	var pente_axe := (marque_tir.y - 35.0) / (marque_tir.x - but) if absf(marque_tir.x - but) > 0.5 else 0.0
	for r in rangs:
		var dans_le_rang := mini(SOUTIEN_PAR_RANG, m - r * SOUTIEN_PAR_RANG)
		var x := clampf(marque_tir.x - sens * (SOUTIEN_RECUL + r * SOUTIEN_RANG), 1.0, 99.0)
		var axe_y := clampf(35.0 + pente_axe * (x - but), BORD, 70.0 - BORD)
		var candidats: Array = []
		for k in 8:
			for cote: float in [1.0, -1.0]:
				# Rangs décalés d'un demi-écart : personne ne cache celui de derrière.
				var y := axe_y + cote * (COULOIR + k * SOUTIEN_ECART + (SOUTIEN_ECART * 0.5 if r % 2 == 1 else 0.0))
				if y >= BORD and y <= 70.0 - BORD:
					candidats.append([absf(y - axe_y), y])
		candidats.sort()
		for k in mini(dans_le_rang, candidats.size()):
			places_attaque.append(Vector2(x, float(candidats[k][1])))
	places_attaque.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for k in m:
		resultat[str(attaque[k][1])] = places_attaque[k]
	return resultat


## Buteur d'une scène de tir (vedette de l'équipe qui a le ballon), "" sans lui.
static func buteur(scene: Dictionary) -> String:
	var camp := int(scene.get("possession", -1))
	for joueur: Variant in scene.get("players", []):
		if joueur is Dictionary and joueur.get("featured", false) and int(joueur.get("side", -1)) == camp:
			return str(joueur.get("id", ""))
	return ""


## Ligne de but visée par une scène de tir au but (ballon du moteur posé sur cette ligne).
static func poteaux_x(scene: Dictionary) -> float:
	var ballon: Variant = scene.get("ball")
	var x := float(ballon.get("x", 50.0)) if ballon is Dictionary else 50.0
	if absf(x - 50.0) > 1.0:
		return 100.0 if x > 50.0 else 0.0
	return but_x(int(scene.get("possession", 0)))


## Scène de transformation (plan déduit du moteur) avec les places de la loi 8 : défense dans
## son en-but, équipe du buteur derrière le ballon. Rend la scène telle quelle sans marque.
static func transformation(scene: Dictionary) -> Dictionary:
	var origine: Variant = scene.get("origin")
	var camp := int(scene.get("possession", -1))
	if not origine is Dictionary or not origine.has("x") or not origine.has("y") or camp not in [0, 1]:
		return scene
	var marque_tir := Vector2(float(origine.x), float(origine.y))
	var nouvelles := places(scene.get("players", []), camp, marque_tir, buteur(scene))
	var copie := scene.duplicate()
	var joueurs: Array = []
	for joueur: Variant in scene.get("players", []):
		if joueur is Dictionary and nouvelles.has(str(joueur.get("id", ""))):
			var place: Dictionary = joueur.duplicate()
			place.x = (nouvelles[str(joueur.id)] as Vector2).x
			place.y = (nouvelles[str(joueur.id)] as Vector2).y
			joueurs.append(place)
		else:
			joueurs.append(joueur)
	copie.players = joueurs
	return copie


## Défenseurs qui chargent le buteur d'une transformation (loi 8), dès sa course d'élan : la même
## scène, les défenseurs (camp opposé à `possession`) sortis de leur en-but vers le ballon. Rend la
## scène telle quelle sans marque.
static func charge(scene: Dictionary) -> Dictionary:
	var origine: Variant = scene.get("origin")
	var camp := int(scene.get("possession", -1))
	if not origine is Dictionary or not origine.has("x") or not origine.has("y") or camp not in [0, 1]:
		return scene
	var marque_tir := Vector2(float(origine.x), float(origine.y))
	var defense: Array = []
	for joueur: Variant in scene.get("players", []):
		if joueur is Dictionary and int(joueur.get("side", -1)) == 1 - camp:
			defense.append([float(joueur.get("y", 35.0)), str(joueur.get("id", ""))])
	defense.sort()
	var rang := {}
	for k in defense.size():
		rang[str(defense[k][1])] = k
	var copie := scene.duplicate()
	var joueurs: Array = []
	for joueur: Variant in scene.get("players", []):
		if joueur is Dictionary and rang.has(str(joueur.get("id", ""))):
			var place: Dictionary = joueur.duplicate()
			var depuis := Vector2(float(joueur.get("x", 50.0)), float(joueur.get("y", 35.0)))
			var vers := marque_tir - depuis
			var longueur := vers.length()
			if longueur > 1.0:
				var pas := minf(CHARGE * float(CHARGE_ETAGE[int(rang[str(joueur.id)]) % CHARGE_ETAGE.size()]), longueur * CHARGE_PART)
				var p := depuis + vers / longueur * pas
				place.x = clampf(p.x, -EN_BUT, 100.0 + EN_BUT)
				place.y = clampf(p.y, BORD, 70.0 - BORD)
			joueurs.append(place)
		else:
			joueurs.append(joueur)
	copie.players = joueurs
	return copie


## Axe du tir (repère du moteur) : des poteaux vers la marque, unitaire.
static func axe(scene: Dictionary) -> Vector2:
	var origine: Variant = scene.get("origin")
	var but := poteaux_x(scene)
	if not origine is Dictionary:
		return Vector2(-1.0 if but > 50.0 else 1.0, 0.0)
	var a := Vector2(float(origine.get("x", 50.0)) - but, float(origine.get("y", 35.0)) - 35.0)
	return a.normalized() if a.length() > 0.5 else Vector2(-1.0 if but > 50.0 else 1.0, 0.0)


## Buteur posé `recul` m derrière le ballon, dans l'axe des poteaux (élan) ; ballon sur la marque.
static func elan(scene: Dictionary, recul: float) -> Dictionary:
	var origine: Variant = scene.get("origin")
	var id := buteur(scene)
	if not origine is Dictionary or id.is_empty():
		return scene.duplicate()
	var a := axe(scene)
	var copie := scene.duplicate()
	copie.ball = {"x": float(origine.x), "y": float(origine.y)}
	var joueurs: Array = []
	for joueur: Variant in scene.get("players", []):
		if joueur is Dictionary and str(joueur.get("id", "")) == id:
			var place: Dictionary = joueur.duplicate()
			place.x = clampf(float(origine.x) + a.x * recul, -EN_BUT, 100.0 + EN_BUT)
			place.y = clampf(float(origine.y) + a.y * recul, 0.5, 69.5)
			joueurs.append(place)
		else:
			joueurs.append(joueur)
	copie.players = joueurs
	return copie


## Position du ballon d'un tir au but à la part `u` (0 à 1) de son vol (repère de la vue) : il
## passe la ligne de but (`cible`) au-dessus de la barre et retombe AU_DELA m plus loin.
static func vol(depart: Vector3, cible: Vector3, u: float) -> Vector3:
	u = clampf(u, 0.0, 1.0)
	var plat := Vector3(cible.x - depart.x, 0.0, cible.z - depart.z)
	var distance := plat.length()
	if distance < 0.5:
		return depart.lerp(cible, u)
	var fin := Vector3(cible.x, BALLON_AU_SOL, cible.z) + plat / distance * AU_DELA
	var ligne := distance / (distance + AU_DELA)
	var sol_ligne := lerpf(depart.y, BALLON_AU_SOL, ligne)
	var fleche := clampf((BARRE + AU_DESSUS - sol_ligne) / (4.0 * ligne * (1.0 - ligne)), 1.0, 20.0)
	var p := depart.lerp(fin, u)
	p.y = lerpf(depart.y, BALLON_AU_SOL, u) + 4.0 * fleche * u * (1.0 - u)
	return p


## Durée du vol d'un tir au but (s).
static func duree_vol(depart: Vector3, cible: Vector3) -> float:
	var distance := Vector2(cible.x - depart.x, cible.z - depart.z).length() + AU_DELA
	return clampf(distance / VITESSE_VOL, float(VOL[0]), float(VOL[1]))


## Places des partenaires autour du marqueur debout en `centre` (repère de la vue), en éventail
## du côté du terrain (`sens` : +1 si son équipe attaque vers +x).
static func autour(centre: Vector3, sens: float, n: int) -> Array[Vector3]:
	var regard := atan2(-sens, 0.0)
	var resultat: Array[Vector3] = []
	for k in mini(n, ECARTS_AUTOUR.size()):
		var angle := regard + float(ECARTS_AUTOUR[k])
		var p := centre + Vector3(sin(angle), 0.0, cos(angle)) * AUTOUR
		resultat.append(Vector3(clampf(p.x, -54.5, 54.5), 0.0, clampf(p.z, -34.5, 34.5)))
	return resultat


## Place de l'arbitre pendant un tir au but (repère de la vue) : à ARBITRE_TIR.x m devant la marque
## vers les poteaux, ARBITRE_TIR.y m sur le côté (côté du milieu du terrain) : dans le plan, sans
## masquer le buteur ni les perches.
const ARBITRE_TIR := Vector2(8.0, 6.0)
static func place_arbitre_tir(marque_vue: Vector3, poteaux_vue_x: float) -> Vector3:
	var vers := Vector3(poteaux_vue_x - marque_vue.x, 0.0, -marque_vue.z)
	if vers.length() < 0.5:
		return marque_vue
	vers = vers.normalized()
	var cote := Vector3(-vers.z, 0.0, vers.x)
	if (marque_vue + cote).z * signf(marque_vue.z if absf(marque_vue.z) > 0.5 else 1.0) > absf(marque_vue.z):
		cote = -cote
	var p := marque_vue + vers * minf(ARBITRE_TIR.x, marque_vue.distance_to(Vector3(poteaux_vue_x, 0.0, 0.0)) * 0.5) + cote * ARBITRE_TIR.y
	return Vector3(clampf(p.x, -54.0, 54.0), 0.0, clampf(p.z, -34.0, 34.0))


## Place de l'arbitre qui accorde l'essai aplati en `point` (repère de la vue).
static func place_arbitre(point: Vector3) -> Vector3:
	var sens := signf(point.x) if absf(point.x) > 0.5 else 1.0
	var cote := -1.0 if point.z - ARBITRE_ECART >= -34.0 else 1.0
	return Vector3(clampf(point.x + sens * 0.5, -54.5, 54.5), 0.0, point.z + cote * ARBITRE_ECART)
