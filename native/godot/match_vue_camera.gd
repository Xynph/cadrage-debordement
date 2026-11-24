extends RefCounted
## Caméra suivie de la vue 3D du match (TV, contact, vue de dessus, plan large, sortie) : point visé,
## recul sous le toit de la tribune, recentrage borné et ballon gardé à l'image.
## Fonctions statiques sur la vue (`v`, NativeMatchView de match_view.gd), qui garde tout l'état ;
## découpées de match_view.gd le 24/11/2026 sans changement de comportement.

const Gestes = preload("res://match_gestes.gd")
const VueVisee = preload("res://match_vue_visee.gd")
const VueJoueurs = preload("res://match_vue_joueurs.gd")

## Caméras de retransmission (TV) et « au contact » (action), en perspective depuis le 18 novembre
## 2026 (orthographiques avant, TV à 41° et 42 à 64 m de champ). Seule la direction de ces décalages
## compte : la distance découle de la hauteur visible voulue au point visé et de l'angle de champ.
## TV : plein travers, 16° au-dessus de l'horizon, comme la caméra principale d'une tribune ;
## action : plus près, plus ouverte, un peu de biais.
## 19 novembre 2026 : à 28°, le haut de l'image (28° - 12° de demi-champ = 16° sous l'horizon)
## passait à 2 m à peine au-dessus du premier rang de la tribune d'en face : le public n'apparaissait
## que sur les coups de pied (caméra relevée vers le ballon haut). À 24°, les premiers rangs d'en face
## bordent le haut de l'image dès que le jeu est au milieu ou dans la moitié lointaine ; près de la
## touche proche, la grue relève toujours la vue jusqu'au même plafond (INCLINAISON_TV_MAX).
## 19 novembre 2026 (soir) : à 24°, avec 26 à 42 m de hauteur visible, les joueurs ne faisaient que 40
## à 60 px de haut (1280 x 720), vus de dessus, et la tribune d'en face 5 à 8 % de l'image au milieu.
## Axe à 16° (caméra principale d'une tribune basse) et hauteur visible resserrée (TV_TAILLE, SUIVI et
## HAUTEUR de match_cadrage.gd) : à 19 m de hauteur visible, jeu au milieu, caméra à 12 m de haut,
## joueur au point visé d'environ 68 px, bas de l'image plongeant à 28°, haut de l'image à 4° sous
## l'horizon : le pied de la tribune d'en face est à 13 % du haut (19 % dans la moitié lointaine).
## Sur la touche proche, la grue monte à 26° au plus (bas de l'image sous PLONGEE_TV_MAX).
const TV_OFFSET := Vector3(0.0, 0.2756, 0.9613)
const ACTION_OFFSET := Vector3(0.24, 0.5, 0.832)
## Caméra-grue : quand le jeu approche de la touche proche (z du point visé entre GRUE_DEBUT et
## GRUE_FIN), la caméra monte et plonge jusqu'à GRUE_ANGLE degrés de plus, comme la caméra
## principale d'une tribune qui suit le jeu le long de sa touche : la tribune proche reste sous
## l'image, au lieu de remplir le bas de l'écran.
## 18 novembre 2026 (soir) : 18° de grue rendaient la vue trop plongeante près de la touche proche
## (joueurs vus du dessus) ; la grue monte de 10° au plus et l'inclinaison totale est plafonnée à
## INCLINAISON_MAX degrés au-dessus de l'horizon, TV et contact : les joueurs restent vus de 3/4. Le
## toit de la tribune proche est alors franchi par la caméra qui avance (pose_camera), pas qui plonge.
const GRUE_DEBUT := 4.0
const GRUE_FIN := 30.0
const GRUE_ANGLE := 10.0
const INCLINAISON_MAX := 38.0

## Angle de champ vertical (degrés) : téléobjectif de retransmission en TV, plus ouvert au contact.
const TV_CHAMP := 24.0
const ACTION_CHAMP := 36.0
## La caméra recule librement, sauf si le bas de l'image passerait sous le bord avant du toit de la
## tribune proche (TOIT_Z, TOIT_Y) : elle avance alors en ouvrant son angle, jusqu'à CHAMP_MAX ; la
## hauteur visible au point visé ne change pas.
const TOIT_Z := 54.6
const TOIT_Y := 13.0
const CHAMP_MAX := 64.0
## Plongée du bas de l'image (inclinaison + demi-angle de champ, degrés), TV et contact. 18 novembre
## 2026 (nuit) : près de la touche proche, l'axe restait sous INCLINAISON_MAX mais la caméra qui
## avançait sous le toit ouvrait son angle jusqu'à CHAMP_MAX : le bas de l'image plongeait à 70° et
## les joueurs proches étaient vus du dessus. L'angle s'ouvre désormais au plus jusqu'à cette
## plongée ; au-delà, la caméra avance à angle constant (hauteur visible un peu plus serrée).
const PLONGEE_MAX := 56.0
## 19 novembre 2026 : la vue TV restait un peu haute près de la touche proche (38° d'axe, bas de l'image
## à 56°). La caméra TV a ses propres plafonds, plus bas (retransmission vue de la tribune, joueurs de
## 3/4) ; la caméra au contact garde INCLINAISON_MAX et PLONGEE_MAX.
## 19 novembre 2026 (soir) : axe TV de base à 16° (TV_OFFSET), grue comprise 26° au plus ; plafonds
## abaissés d'autant (28° d'axe, 44° pour le bas de l'image) : près de la touche proche, la caméra qui
## avance sous le toit ouvre moins son angle et les joueurs proches restent vus de 3/4.
const INCLINAISON_TV_MAX := 28.0
const PLONGEE_TV_MAX := 44.0

## Hauteur visible (m) au point visé de la caméra de base (hors temps fort). Le cadrage des temps
## forts (match_cadrage.gd) la règle ensuite selon les joueurs utiles. 19 novembre 2026 (soir) : 30 m
## laissaient des joueurs de 40 px ; 18 m (axe à 16°) : environ 70 px au point visé.
## 19 novembre 2026 (nuit) : caméra au contact resserrée de 16 à 12 m (SUIVI.action de match_cadrage.gd
## 10 à 12,5 m) : avec la vue TV basse de 15 à 19 m, 16 m au contact donnaient presque le même plan.
## Contact au plus 0,85 fois le plan TV le plus serré : joueurs au point visé environ 1,35 fois plus grands.
const TV_TAILLE := 18.0
const ACTION_TAILLE := 12.0
## Mi-temps et fin de match : plan large de tout le terrain, vu de haut au-dessus de la tribune
## proche (rayons au-dessus de son toit) : direction, point visé, recul (m) et angle de champ.
const PLAN_LARGE_OFFSET := Vector3(0.0, 0.64, 0.77)
const PLAN_LARGE_VISE := Vector3(0.0, 0.0, 4.0)
const PLAN_LARGE_RECUL := 125.0
const PLAN_LARGE_CHAMP := 36.0

## Plan de la sortie : contrechamp depuis le terrain, tourné vers la tribune principale et le
## tunnel, qui suit le groupe (direction, recul en m, angle de champ, lissage en s).
const PLAN_SORTIE_OFFSET := Vector3(0.22, 0.42, -0.88)
const PLAN_SORTIE_RECUL := 36.0
const PLAN_SORTIE_CHAMP := 38.0
const PLAN_SORTIE_LISSAGE := 0.6
## Recentrage borné (TV et action) : la touche lointaine, la touche proche et les lignes de ballon
## mort, plus TERRAIN_MARGE m, restent près des bords de l'image (BORD_*, en part de l'image) : la
## tribune n'en occupe qu'une bande. Le ballon reste toujours dans la zone sûre (BALLON_SUR des bords).
const TERRAIN := Vector2(55.0, 35.0)
const TERRAIN_MARGE := 3.0
const BORD_HAUT := 0.12
## Caméra TV : bande de tribune d'en face un peu plus haute en haut de l'image (public visible).
## 19 novembre 2026 (soir) : avec l'axe à 16°, les abords lointains (touche à panneaux, 8 m) prennent
## plus de place : à 0,2, la borne repoussait le point visé vers la touche proche dès le milieu du
## terrain (et la caméra sous le toit, angle grand ouvert). À 0,28 : tribune d'en face jusqu'à environ
## 20 % de l'image, le terrain et ses abords toujours plus de 70 %.
const BORD_HAUT_TV := 0.28
## Vue tactique (de dessus) : profondeur gardée de part et d'autre de l'axe (m). 41 m s'arrêtait
## avant les tribunes latérales (premier rang à 46 m) ; 45 m (x 1,08 de marge) montre leurs deux
## premiers rangs.
const TACTIQUE_PROFONDEUR := 45.0
const BORD_BAS := 0.9
const BORD_COTE := 0.04
const BALLON_SUR := 0.2
## Le recentrage borné est amorti (secondes) ; seule une sortie du ballon hors de BALLON_LIMITE
## des bords est corrigée d'emblée.
const BORNE_LISSAGE := 0.35
const BALLON_LIMITE := 0.16
## Retard maximal du point visé sur le ballon, en part de la hauteur visible de base. Un ballon qui
## réapparaît plus loin que ce retard du point visé fait couper la caméra ; plus près, elle glisse.
const RETARD_MAX := 0.3

static func _fit_camera(v: NativeMatchView, delta: float = 0.0, cut: bool = false) -> void:
	if not is_instance_valid(v._camera):
		return
	v._camera_framed = true
	if v._camera_mode != "tactical":
		var base := ACTION_TAILLE if v._camera_mode == "action" else TV_TAILLE
		# Ballon absent : la caméra garde son point visé.
		var desired := v._ball.global_position if v._ball.visible else v._camera_focus
		if cut:
			v._camera_focus = desired
		else:
			v._camera_focus = v._camera_focus.lerp(desired, 1.0 - exp(-5.0 * delta))
			# Bound the follow delay during a long authored pass; the ball must
			# stay in the comfortable middle area even at the in-goal corners.
			var lag := v._camera_focus - desired
			v._camera_focus = desired + lag.limit_length(base * RETARD_MAX)
		var offset := offset_suivi(v, ACTION_OFFSET if v._camera_mode == "action" else TV_OFFSET, v._camera_focus.z)
		var look := v._camera_focus
		var size := base
		var wide := size
		var screen := v.get_viewport().get_visible_rect().size
		if v.sortie and v.plan_sortie:
			# Sortie montrée de près : contrechamp qui suit le groupe vers le tunnel (prime sur le plan large).
			var vise := VueJoueurs._vise_sortie(v)
			v._sortie_vise = vise if cut or delta <= 0.0 else v._sortie_vise.lerp(vise, 1.0 - exp(-delta / PLAN_SORTIE_LISSAGE))
			var sens := PLAN_SORTIE_OFFSET.normalized()
			v._camera_look = v._sortie_vise
			v._camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			v._camera.global_transform = Transform3D(Basis.looking_at(-sens, Vector3.UP), v._sortie_vise + sens * PLAN_SORTIE_RECUL)
			v._camera.fov = PLAN_SORTIE_CHAMP
			return
		if v._plan_large:
			# Mi-temps, fin de match : tout le terrain, sans recadrage.
			var direction := PLAN_LARGE_OFFSET.normalized()
			v._camera_look = PLAN_LARGE_VISE
			v._camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			v._camera.global_transform = Transform3D(Basis.looking_at(-direction, Vector3.UP), PLAN_LARGE_VISE + direction * PLAN_LARGE_RECUL)
			v._camera.fov = PLAN_LARGE_CHAMP
			v._camera.size = 2.0 * PLAN_LARGE_RECUL * tan(deg_to_rad(PLAN_LARGE_CHAMP * 0.5))
			return
		if v._cadrage:
			# Pendant un temps fort : l'action est cadrée de près, le ballon toujours dans le champ.
			var close: Array = v._cadrage.frame_camera(look, size, offset, screen.x / maxf(screen.y, 1.0), v._camera_mode, delta, cut)
			look = close[0]
			size = close[1]
			offset = close[2]
			if v._cadrage.has_method("dans_l_axe") and v._cadrage.dans_l_axe():
				# Tir au but filmé dans l'axe (match_cadrage.gd) : posé tel quel, sans recadrage de geste
				# ni bornes de la caméra de tribune.
				if v._gestes:
					v._gestes.reset_framing()
				_poser_camera(v, look, size, offset)
				return
		if v._gestes:
			# Pendant un geste : rapprochement amorti (et léger pivot lent en TV), puis retour.
			var framed: Array = v._gestes.frame_camera(look, size, offset, screen.x / maxf(screen.y, 1.0), v._camera_mode, delta)
			look = framed[0]
			size = framed[1]
			offset = framed[2]
			if float(v._gestes.zoom) > 0.0:
				# Essai dans un coin : pivot limité et point visé gardé dans l'aire de jeu (pas de tribune).
				var suivi := offset_suivi(v, ACTION_OFFSET if v._camera_mode == "action" else TV_OFFSET, v._camera_focus.z)
				offset = VueVisee.borner_pivot(look, offset, suivi)
				look = look.lerp(VueVisee.borner_visee(look), smoothstep(0.0, 1.0, float(v._gestes.zoom)))
			if v._cadrage:
				# Temps fort : le cadrage du geste garde lui aussi le ballon dans le champ.
				look = v._cadrage.garder_ballon(look, size, offset, screen.x / maxf(screen.y, 1.0))
		if v._camera_mode == "action":
			# Caméra au contact : point visé toujours ramené dans l'aire de jeu (essai en coin : le
			# terrain, pas la tribune) ; le ballon reste gardé à l'image plus bas.
			look = VueVisee.borner_visee(look, VueVisee.VISEE_CONTACT)
		# Jamais de champ dégénéré, quel que soit le recadrage.
		if not is_finite(size) or size < 2.0 or not look.is_finite() or not offset.is_finite():
			look = v._camera_focus
			size = wide
			offset = offset_suivi(v, ACTION_OFFSET if v._camera_mode == "action" else TV_OFFSET, v._camera_focus.z)
		# Pivot amorti autour du point visé quand un poteau masquerait l'action (caméra au contact) ou
		# passerait au premier plan, tout près de l'objectif (TV et contact ; cherché sur le point visé
		# final de l'image précédente, déjà stable d'une image à l'autre).
		var contournement := VueVisee.contournement_poteaux(v, look if cut or delta <= 0.0 else v._camera_look, size, offset)
		if cut or delta <= 0.0:
			v._contournement = contournement
			v._contournement_vitesse = 0.0
		else:
			var pas_contournement: Array = Gestes._damp1(v._contournement, contournement, v._contournement_vitesse, delta)
			v._contournement = pas_contournement[0]
			v._contournement_vitesse = pas_contournement[1]
		if absf(v._contournement) > 0.0001:
			offset = offset.rotated(Vector3.UP, v._contournement)
		# Recentrage borné, amorti (pas d'à-coup quand une borne entre en jeu) ; le ballon ne sort
		# jamais de l'image, même pendant l'amortissement.
		var aspect := screen.x / maxf(screen.y, 1.0)
		var borne := _borner(v, look, size, offset, aspect) - look
		if cut or delta <= 0.0:
			v._borne = borne
			v._borne_vitesse = Vector3.ZERO
		else:
			var pas: Array = Gestes._damp3(v._borne, borne, v._borne_vitesse, delta, BORNE_LISSAGE)
			v._borne = pas[0]
			v._borne_vitesse = pas[1]
		look += v._borne
		if v._ball.visible:
			var vue := Basis.looking_at(-offset, Vector3.UP)
			var profondeur := Vector3(vue.z.x, 0.0, vue.z.z).normalized()
			# Ni hors de l'image, ni sous le bandeau du score ou la légende du direct.
			var haut := BALLON_LIMITE + (float(v._cadrage.couvert_haut) if v._cadrage else 0.0)
			var bas := 1.0 - BALLON_LIMITE - (float(v._cadrage.couvert_bas) if v._cadrage else 0.0)
			look += profondeur * _garder_ballon(v, 0.0, look, size, offset, aspect, profondeur, v._ball.global_position, 1, haut, bas)
			var largeur := Vector3(vue.x.x, 0.0, vue.x.z).normalized()
			look += largeur * _garder_ballon(v, 0.0, look, size, offset, aspect, largeur, v._ball.global_position, 0, BALLON_LIMITE, 1.0 - BALLON_LIMITE)
		_poser_camera(v, look, size, offset)
		return
	if v._gestes:
		v._gestes.reset_framing()
	v._camera_focus = Vector3.ZERO
	v._camera_look = Vector3.ZERO
	v._camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	v._camera.position = Vector3(0, 150, 5)
	v._camera.look_at(Vector3.ZERO)
	var viewport_size := v.get_viewport().get_visible_rect().size
	if viewport_size.y <= 0:
		return
	var aspect := viewport_size.x / viewport_size.y
	var half_height := 0.0
	# Tactical retains the entire pitch and its five-metre presentation apron, plus the first rows
	# of both side stands (TACTIQUE_PROFONDEUR) : le public borde le terrain vu de dessus.
	for x in [-56.0, 56.0]:
		for z in [-TACTIQUE_PROFONDEUR, TACTIQUE_PROFONDEUR]:
			var point := v._camera.to_local(Vector3(x, 0, z))
			half_height = maxf(half_height, maxf(absf(point.y), absf(point.x) / aspect))
	v._camera.size = maxf(half_height * 2.16, 88.0)


## Direction de la caméra suivie pour un point visé à `profondeur` (z) : celle de base, relevée
## progressivement près de la touche proche (caméra-grue, voir GRUE_*). Continue : pas d'à-coup.
## Caméra de biais (contact) : son lacet est rendu progressivement symétrique quand le point suivi
## (`largeur`, x ; par défaut celui de la caméra) approche du bout du terrain vers lequel elle
## regarderait (|x| de PIVOT_DEBUT à PIVOT_FIN) : elle se place alors derrière l'en-but et regarde
## vers l'intérieur du terrain, jamais vers la tribune du bout du terrain.
static func offset_suivi(v: NativeMatchView, base: Vector3, profondeur: float, largeur: float = NAN) -> Vector3:
	if absf(base.x) > 0.0001:
		var x := v._camera_focus.x if is_nan(largeur) else largeur
		# La caméra regarde vers -offset : le bout du terrain regardé est du côté de -base.x.
		var symetrie := smoothstep(VueVisee.PIVOT_DEBUT, VueVisee.PIVOT_FIN, -x * signf(base.x))
		if symetrie > 0.0:
			base = base.rotated(Vector3.UP, -2.0 * symetrie * atan2(base.x, base.z))
	var k := smoothstep(GRUE_DEBUT, GRUE_FIN, profondeur)
	if k <= 0.0:
		return base
	var horizontal := Vector3(base.x, 0.0, base.z)
	var depart := atan2(base.y, horizontal.length())
	# Plafond d'inclinaison (jamais sous l'angle de base) : pas de vue de dessus près de la touche.
	var elevation := minf(depart + deg_to_rad(GRUE_ANGLE) * k, maxf(depart, deg_to_rad(v.inclinaison_max())))
	return (horizontal.normalized() * cos(elevation) + Vector3.UP * sin(elevation)) * base.length()


## Caméra suivie en perspective : `size` est la hauteur visible (m) au point visé `look`, `offset`
## la direction depuis ce point. `_camera.size` garde cette hauteur visible (régie, tests).
static func _poser_camera(v: NativeMatchView, look: Vector3, size: float, offset: Vector3) -> void:
	var pose := pose_camera(v, look, size, offset)
	v._camera_look = look
	v._camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	v._camera.global_transform = Transform3D(Basis.looking_at(-offset, Vector3.UP), pose[0])
	v._camera.fov = pose[1]
	v._camera.size = size


## Position de la caméra et angle de champ vertical (degrés) pour voir `size` m de haut au point
## visé. Au-delà de RECUL_MAX (tribune proche), la caméra avance et ouvre son angle.
static func pose_camera(v: NativeMatchView, look: Vector3, size: float, offset: Vector3) -> Array:
	var direction := offset.normalized()
	var demi := size * 0.5
	var champ := ACTION_CHAMP if v._camera_mode == "action" else TV_CHAMP
	var distance := demi / tan(deg_to_rad(champ * 0.5))
	if direction.z > 0.05 and _sous_le_toit(look, direction, distance, demi):
		# Le bas de l'image passerait sous le toit de la tribune proche : la caméra avance (et
		# ouvre son angle) juste assez pour le franchir, sans que le bas de l'image dépasse PLONGEE_MAX.
		var inclinaison := rad_to_deg(asin(clampf(direction.y, -1.0, 1.0)))
		var ouverture := clampf(2.0 * (v.plongee_max() - inclinaison), champ, CHAMP_MAX)
		var pente := tan(deg_to_rad(ouverture * 0.5))
		var a := demi / pente
		var b := distance
		if _sous_le_toit(look, direction, a, demi):
			# Angle plafonné : la caméra avance à angle constant jusqu'à passer devant le toit
			# (plus près = plus dégagé) ; la hauteur visible se resserre d'autant.
			var proche := 1.0
			var loin := a
			for i in 10:
				var m := (proche + loin) * 0.5
				if _sous_le_toit(look, direction, m, m * pente):
					loin = m
				else:
					proche = m
			return [look + direction * proche, ouverture]
		else:
			for i in 8:
				var m := (a + b) * 0.5
				if _sous_le_toit(look, direction, m, demi):
					b = m
				else:
					a = m
			distance = a
	return [look + direction * distance, rad_to_deg(2.0 * atan(demi / distance))]


## Le rayon du bas de l'image passe sous le bord avant du toit de la tribune proche.
static func _sous_le_toit(look: Vector3, direction: Vector3, distance: float, demi: float) -> bool:
	var camera := look + direction * distance
	if camera.z <= TOIT_Z:
		return false
	var vue := Basis.looking_at(-direction, Vector3.UP)
	var rayon := -vue.z - vue.y * (demi / distance)
	if rayon.z >= -0.0001:
		return true
	return camera.y + rayon.y * ((TOIT_Z - camera.z) / rayon.z) < TOIT_Y


## Coordonnées d'écran (0 à 1, origine en haut à gauche) d'un point vu par la caméra posée sur
## `look`. Un point derrière la caméra est rendu très bas (sous l'image).
static func ecran_camera(v: NativeMatchView, point: Vector3, look: Vector3, size: float, offset: Vector3, aspect: float) -> Vector2:
	var pose := pose_camera(v, look, size, offset)
	var local: Vector3 = Basis.looking_at(-offset, Vector3.UP).inverse() * (point - (pose[0] as Vector3))
	var profondeur := -local.z
	if profondeur < 0.05:
		return Vector2(0.5, 10.0)
	var pente := tan(deg_to_rad(float(pose[1]) * 0.5))
	return Vector2(0.5 + 0.5 * local.x / (profondeur * pente * maxf(aspect, 0.1)), 0.5 - 0.5 * local.y / (profondeur * pente))


## Recentrage borné : le point visé glisse (en profondeur, puis en largeur) juste assez pour que la
## tribune et les abords n'occupent qu'une bande au bord de l'image, sans que le ballon quitte la
## zone sûre. Si l'image est plus grande que le terrain, le terrain y est centré.
static func _borner(v: NativeMatchView, look: Vector3, size: float, offset: Vector3, aspect: float) -> Vector3:
	var ballon := v._ball.global_position if v._ball.visible else look
	var haut_sur := BALLON_SUR
	var bas_sur := 1.0 - BALLON_SUR
	var bord_haut := BORD_HAUT if v._camera_mode == "action" else BORD_HAUT_TV
	var bord_bas := BORD_BAS
	if v._cadrage:
		# L'interface du direct couvre le haut et le bas : le ballon reste dans la partie visible,
		# et ce qui est sous le bandeau ou la légende ne compte pas comme tribune à l'image.
		haut_sur = maxf(haut_sur, float(v._cadrage.couvert_haut) + 0.08)
		bas_sur = minf(bas_sur, 1.0 - float(v._cadrage.couvert_bas) - 0.08)
		bord_haut = maxf(bord_haut, float(v._cadrage.couvert_haut) + 0.02)
		bord_bas = minf(bord_bas, 1.0 - float(v._cadrage.couvert_bas) - 0.02)
	var loin := -TERRAIN.y - TERRAIN_MARGE
	var pres := TERRAIN.y + TERRAIN_MARGE
	var bout := TERRAIN.x + TERRAIN_MARGE
	# Axes de la caméra au sol : un glissement en largeur ne change pas la hauteur à l'écran.
	var vue := Basis.looking_at(-offset, Vector3.UP)
	var largeur := Vector3(vue.x.x, 0.0, vue.x.z).normalized()
	# Profondeur : touche lointaine en haut, touche proche en bas.
	var axe := Vector3(vue.z.x, 0.0, vue.z.z).normalized()
	var bornes := Vector2(
		_seuil(v, look, size, offset, aspect, axe, Vector3(look.x, 0.0, loin), 1, bord_haut, true).x,
		_seuil(v, look, size, offset, aspect, axe, Vector3(look.x, 0.0, pres), 1, bord_bas, false).y)
	var s := clampf(0.0, bornes.x, bornes.y) if bornes.x <= bornes.y else (bornes.x + bornes.y) * 0.5
	if v._camera_mode != "action" and s > 0.0:
		s = _sans_ouvrir(v, look, size, offset, axe, s)
	s = _garder_ballon(v, s, look, size, offset, aspect, axe, ballon, 1, haut_sur, bas_sur)
	look += axe * s
	# Largeur : lignes de ballon mort sur les bords.
	axe = largeur
	bornes = Vector2(
		_seuil(v, look, size, offset, aspect, axe, Vector3(-bout, 0.0, look.z), 0, BORD_COTE, true).x,
		_seuil(v, look, size, offset, aspect, axe, Vector3(bout, 0.0, look.z), 0, 1.0 - BORD_COTE, false).y)
	s = clampf(0.0, bornes.x, bornes.y) if bornes.x <= bornes.y else (bornes.x + bornes.y) * 0.5
	s = _garder_ballon(v, s, look, size, offset, aspect, axe, ballon, 0, BALLON_SUR, 1.0 - BALLON_SUR)
	return look + axe * s


## Caméra TV (19 novembre 2026, soir) : le recentrage qui pousse le point visé vers la touche proche
## (tribune d'en face trop présente) s'arrête avant que la caméra, qui recule avec lui, passe sous le toit
## de la tribune proche et ouvre son angle (pose_camera). Sinon l'image plus ouverte montrerait encore
## plus de tribune d'en face, la borne pousserait plus loin, jusqu'à DECALAGE_MAX : terrain vu de près,
## grand angle, la moitié de l'image hors du terrain. Rend le plus grand décalage dans [0, s] qui garde
## l'angle de champ de la pose sans décalage.
static func _sans_ouvrir(v: NativeMatchView, look: Vector3, size: float, offset: Vector3, axe: Vector3, s: float) -> float:
	var champ := float(pose_camera(v, look, size, offset)[1]) + 0.01
	if float(pose_camera(v, look + axe * s, size, offset)[1]) <= champ:
		return s
	var a := 0.0
	var b := s
	for i in 10:
		var m := (a + b) * 0.5
		if float(pose_camera(v, look + axe * m, size, offset)[1]) > champ:
			b = m
		else:
			a = m
	return a


## Décalage limité (ou imposé) pour que le ballon reste entre `bas` et `haut` sur la coordonnée
## d'écran `c`, en vraie perspective (ballon haut et proche de la caméra compris).
static func _garder_ballon(v: NativeMatchView, s: float, look: Vector3, size: float, offset: Vector3, aspect: float, axe: Vector3, ballon: Vector3, c: int, bas: float, haut: float) -> float:
	var a := _seuil(v, look, size, offset, aspect, axe, ballon, c, haut, true)
	var b := _seuil(v, look, size, offset, aspect, axe, ballon, c, bas, false)
	var permis := Vector2(maxf(a.x, b.x), minf(a.y, b.y))
	return clampf(s, permis.x, permis.y) if permis.x <= permis.y else s


const DECALAGE_MAX := 30.0
## Intervalle [min, max] des décalages s du point visé le long de `axe` pour lesquels la coordonnée
## d'écran `c` (0 : x, 1 : y) de `point` reste sous `cible` (`sous`) ou au-dessus.
static func _seuil(v: NativeMatchView, look: Vector3, size: float, offset: Vector3, aspect: float, axe: Vector3, point: Vector3, c: int, cible: float, sous: bool) -> Vector2:
	var a := -DECALAGE_MAX
	var b := DECALAGE_MAX
	var fa: float = ecran_camera(v, point, look + axe * a, size, offset, aspect)[c]
	var fb: float = ecran_camera(v, point, look + axe * b, size, offset, aspect)[c]
	var croissant := fb > fa
	# Partie valable : du côté où la coordonnée est sous la cible (ou au-dessus).
	var valable_bas := sous == croissant
	if (fa <= cible) == (fb <= cible):
		# Pas de passage : tout ou rien.
		var tout := (fa <= cible) == sous
		if tout:
			return Vector2(-INF, INF)
		# Rien de valable dans la plage : la borne extrême du bon côté.
		return Vector2(-INF, -DECALAGE_MAX) if valable_bas else Vector2(DECALAGE_MAX, INF)
	for i in 11:
		var m := (a + b) * 0.5
		var fm: float = ecran_camera(v, point, look + axe * m, size, offset, aspect)[c]
		if (fm <= cible) == (fa <= cible):
			a = m
			fa = fm
		else:
			b = m
	var limite := (a + b) * 0.5
	return Vector2(-INF, limite) if valable_bas else Vector2(limite, INF)
