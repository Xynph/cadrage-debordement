extends Node3D
## Arbitre des temps forts (13 novembre 2026, liaison entre temps forts, demande de Léo).
##
## Présentation seulement : l'arbitre ne décide rien. Pendant le jeu, il suit le ballon à
## distance, du côté opposé à la caméra (il ne masque pas l'action). Pendant une liaison
## (match_liaison.gd), la régie lui donne une place et des signaux : coup de sifflet (main à
## la bouche), bras tendu vers l'équipe qui bénéficie de la décision (horizontal pour une
## touche ou une mêlée, levé pour une pénalité). Il se déplace à allure bornée (jamais de
## glissade : l'animation avance à la distance parcourue, comme les joueurs) ; il n'est
## replacé d'un coup que sur une coupe de caméra.
##
## Tenue : la couleur la plus lisible face aux deux maillots (noir, vert vif, rose, bleu nuit).

const Presentation = preload("res://match_presentation.gd")
const Athlete = preload("res://match_athlete.gd")
const Kit = preload("res://match_kit.gd")
const ApresEssai = preload("res://match_apres_essai.gd")
const TENUES := [Color("16181b"), Color("b7e23a"), Color("e2457f"), Color("23347a")]
const ALLURE_MAX := 6.2      # m/s
const ACCELERATION := 4.5    # m/s²
const RECUL := 7.5           # distance au ballon pendant le jeu
const PROCHE := 2.5          # en deçà, il ne bouge pas pour un petit déplacement du ballon
## Essai accordé (19 novembre 2026) : dès que le geste d'essai de la vue est aplati, il rejoint le
## point d'aplati (à côté, match_apres_essai.gd `place_arbitre`), siffle ESSAI_SIFFLET s, puis, à
## moins de ESSAI_PROCHE m du point, tend le bras vers lui (un peu vers le bas) ESSAI_BRAS s.
const ESSAI_SIFFLET := 0.7
const ESSAI_PROCHE := 5.0
const ESSAI_BRAS := 3.0
const ESSAI_BRAS_HAUTEUR := -0.45
## Lois (26 novembre 2026, demande de Léo) : programme donné par la régie au début d'un plan (`loi`).
##   - coup franc : coup de sifflet LOI_SIFFLET s, puis BRAS PLIÉ vers l'équipe qui en bénéficie (bras
##     horizontal, avant-bras levé, coude à 90°), différent du bras tendu de la pénalité ;
##   - essai de pénalité : il court sous les poteaux, siffle LOI_SIFFLET s une fois arrivé (à moins de
##     LOI_ARRIVE m), puis lève le bras droit au-dessus de la tête (essai accordé), face au terrain.
const LOI_SIFFLET := 0.6
const LOI_ARRIVE := 1.2
const LOI_COUDE := 1.6
## Bras plié : longueur du bras (épaule-coude) à l'horizontale et de l'avant-bras à la verticale (m).
const COUDE_BRAS := 0.27
const COUDE_AVANT_BRAS := 0.3
## Bras levé à la verticale (hauteur_bras : angle de LEVE * 0,7 rad au-dessus de l'horizontale).
const LEVE := 2.25

var view: Node3D
var model: Node3D
var rig: Skeleton3D
var animation: AnimationPlayer
var adapte := false
var palier := -1
var _repos := StringName()
var _marche := StringName()
var _course := StringName()
var cible := Vector3.ZERO
## Vrai pendant une liaison : la régie choisit sa place ; sinon il suit le ballon.
var dirige := false
var vitesse := Vector3.ZERO
## Signal en cours : "" , "sifflet" ou "bras" ; direction du bras (repère du monde) et hauteur (0 horizontal, 1 levé).
var signal_bras := ""
var direction_bras := Vector3.RIGHT
var hauteur_bras := 0.0
var _poids := 0.0
var _signal_vu := ""
var _regard := Vector3.ZERO
## Essai qu'il accorde : {"point": Vector3, "t": s depuis l'aplati, "bras": instant où il tend le
## bras (-1 avant)} ; vide hors essai ou quand la régie le dirige (liaison).
var essai: Dictionary = {}
## Programme d'une loi (coup franc, essai de pénalité) : {"genre", "place" ou "point", "regard",
## "dir" (bras), "t", "arrive"} ; vide sinon. La régie le pose et l'efface (match_temps_forts_lecture.gd).
var loi: Dictionary = {}


func _init(owner: Node3D) -> void:
	view = owner
	name = "Arbitre"


func preparer() -> bool:
	if view.get("_athlete_scene") == null:
		return false
	model = (view._athlete_scene as PackedScene).instantiate() as Node3D
	add_child(model)
	model.set_meta("athlete_id", "arbitre")
	var bornes: AABB = view._model_bounds(model, model)
	if bornes.size.y > 0.001:
		var calibration := 1.86 / bornes.size.y
		model.scale = Vector3.ONE * calibration
		model.position.y = -bornes.position.y * calibration
	Athlete.prepare(model)
	habiller()
	rig = Presentation.rig_for(model)
	animation = view._find_animation(model)
	if animation:
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: StringName in animation.get_animation_list():
			if str(clip).ends_with("Man_Idle"): _repos = clip
			if str(clip).ends_with("Man_Run"): _course = clip
			if str(clip).ends_with("Man_Walk"): _marche = clip
		for clip: StringName in [_repos, _course, _marche]:
			if not clip.is_empty(): animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		var adaptees: Variant = view.get("_animations_adaptees")
		if adaptees != null and adaptees.equiper(animation):
			adapte = true
			_repos = adaptees.repos()
		if not _repos.is_empty(): animation.play(_repos)
	return true


## Tenue la plus lisible face aux deux équipes (et à la pelouse).
func habiller() -> void:
	if model == null:
		return
	var kits: Array = view.get("_kits") if view.get("_kits") is Array else []
	var meilleure: Color = TENUES[0]
	var score := -1.0
	for couleur: Color in TENUES:
		var c := minf(Kit._grass_contrast(couleur), 3.0)
		for kit: Variant in kits:
			if kit is Dictionary: c = minf(c, Kit._contrast(couleur, kit.shirt))
		if c > score:
			score = c
			meilleure = couleur
	Athlete.dress(model, {"shirt": meilleure, "detail": meilleure.lightened(0.35), "shorts": Color("111214")}, "arbitre")


## Coupe de caméra : il est déjà à sa place.
func placer(lieu: Vector3, regard: Vector3 = Vector3.INF) -> void:
	position = Vector3(lieu.x, 0.0, lieu.z)
	cible = position
	vitesse = Vector3.ZERO
	if regard.is_finite() and Vector2(regard.x - position.x, regard.z - position.z).length() > 0.1:
		rotation.y = atan2(regard.x - position.x, regard.z - position.z)


## Place qu'il prend pendant le jeu : à RECUL m du ballon, côté opposé à la caméra.
func place_de_jeu(ballon: Vector3) -> Vector3:
	var cote := -1.0 if ballon.z > -24.0 else 1.0
	return Vector3(clampf(ballon.x - 2.5, -52.0, 52.0), 0.0, clampf(ballon.z + cote * RECUL, -34.0, 34.0))


func _process(delta: float) -> void:
	if model == null or delta <= 0.0:
		return
	var ballon: Vector3 = view._ball.global_position if is_instance_valid(view.get("_ball")) and view._ball.visible else position
	_regard = ballon
	if _jouer_loi(delta):
		pass
	elif _accorder_essai(delta):
		pass
	elif not dirige:
		var voulu := place_de_jeu(ballon)
		if Vector2(voulu.x - cible.x, voulu.z - cible.z).length() > PROCHE or Vector2(voulu.x - position.x, voulu.z - position.z).length() > RECUL:
			cible = voulu
	var avant := position
	var ecart := Vector3(cible.x - position.x, 0.0, cible.z - position.z)
	var distance := ecart.length()
	# Allure voulue : il freine pour s'arrêter à sa place, sans dépasser ALLURE_MAX.
	var allure := minf(ALLURE_MAX, sqrt(2.0 * ACCELERATION * maxf(0.0, distance - 0.05)))
	var voulue := ecart / distance * allure if distance > 0.05 else Vector3.ZERO
	vitesse = vitesse.move_toward(voulue, ACCELERATION * delta)
	position += vitesse * delta
	var mouvement := position - avant
	var v := mouvement.length() / delta
	# Il court face à sa course, et regarde le ballon à l'arrêt (rotation bornée).
	var vise := atan2(mouvement.x, mouvement.z) if v > 0.6 else atan2(_regard.x - position.x, _regard.z - position.z)
	if v > 0.6 or Vector2(_regard.x - position.x, _regard.z - position.z).length() > 0.5:
		rotation.y += clampf(angle_difference(rotation.y, vise), -5.0 * delta, 5.0 * delta)
	_animer(v, mouvement.length(), delta)
	_signaler(delta)


## Essai aplati à l'écran (geste d'essai de la vue) : il le rejoint, siffle, puis tend le bras vers
## le point d'aplati. Rend vrai tant qu'il accorde l'essai (sa place est alors celle de l'essai).
func _accorder_essai(delta: float) -> bool:
	var point := _point_essai()
	if dirige or not point.is_finite():
		if not essai.is_empty():
			essai = {}
			if not dirige:
				signal_bras = ""
		return false
	if essai.is_empty() or (essai.point as Vector3).distance_to(point) > 0.5:
		essai = {"point": point, "t": 0.0, "bras": -1.0}
	essai.t = float(essai.t) + delta
	cible = ApresEssai.place_arbitre(point)
	_regard = point
	var t := float(essai.t)
	var pres := Vector2(position.x - point.x, position.z - point.z).length() < ESSAI_PROCHE
	if float(essai.bras) < 0.0 and t >= ESSAI_SIFFLET and pres:
		essai.bras = t
	if t < ESSAI_SIFFLET:
		signal_bras = "sifflet"
	elif float(essai.bras) >= 0.0 and t < float(essai.bras) + ESSAI_BRAS:
		signal_bras = "bras"
		direction_bras = Vector3(point.x - position.x, 0.0, point.z - position.z)
		hauteur_bras = ESSAI_BRAS_HAUTEUR
	else:
		signal_bras = ""
	return true


## Programme d'une loi (coup franc, essai de pénalité). Rend vrai tant qu'il dure : sa place et
## ses signaux sont alors ceux de la loi.
func _jouer_loi(delta: float) -> bool:
	if not loi.is_empty() and not dirige:
		# La régie a repris la main (fin du temps fort, liaison) : le programme s'arrête.
		loi = {}
		signal_bras = ""
	if loi.is_empty():
		return false
	loi.t = float(loi.get("t", 0.0)) + delta
	var t := float(loi.t)
	var regard: Vector3 = loi.get("regard", position + Vector3.BACK)
	match str(loi.get("genre", "")):
		"coup-franc":
			# Coup de sifflet en rejoignant la marque ; bras plié une fois arrivé (au plus tard LOI_COUDE s).
			var place: Vector3 = loi.place
			cible = place
			_regard = regard
			var pose := Vector2(position.x - place.x, position.z - place.z).length() < LOI_ARRIVE or t >= LOI_COUDE
			if t < LOI_SIFFLET or not pose:
				signal_bras = "sifflet" if t < LOI_SIFFLET + 0.4 else ""
			else:
				signal_bras = "coude"
				direction_bras = loi.dir
				hauteur_bras = 0.0
		"essai-penalite":
			var point: Vector3 = loi.point
			cible = point
			var pres := Vector2(position.x - point.x, position.z - point.z).length() < LOI_ARRIVE
			if float(loi.get("arrive", -1.0)) < 0.0 and pres:
				loi.arrive = t
			var arrive := float(loi.get("arrive", -1.0))
			# En course : il regarde où il va ; arrivé, face au terrain.
			_regard = regard if arrive >= 0.0 else point
			if arrive < 0.0:
				signal_bras = ""
			elif t < arrive + LOI_SIFFLET:
				signal_bras = "sifflet"
			else:
				signal_bras = "bras"
				direction_bras = loi.dir
				hauteur_bras = LEVE
		_:
			return false
	return true


## Point d'aplati de l'essai que la vue met en scène, une fois le ballon au sol ; INF sinon.
func _point_essai() -> Vector3:
	var gestes: Variant = view.get("_gestes")
	if gestes == null or not gestes.active() or str(gestes.phase) not in ["essai", "essai_maul"] or not gestes.essai_aplati():
		return Vector3.INF
	var point: Vector3 = gestes.target
	return Vector3(point.x, 0.0, point.z)


func _animer(v: float, parcouru: float, delta: float) -> void:
	if animation == null:
		return
	var bouge := v > 0.05
	var clip := _repos
	var foulee := 4.0
	if adapte:
		var adaptees: Variant = view._animations_adaptees
		palier = adaptees.palier(v, palier) if bouge else -1
		if bouge:
			clip = adaptees.clip(maxi(palier, 0))
			foulee = adaptees.allure(maxi(palier, 0))
	elif bouge:
		var court := v > 2.8
		clip = _course if court else _marche
		foulee = 4.0 if court else 1.6
	if not clip.is_empty() and animation.current_animation != clip:
		animation.play(clip, 0.2)
	animation.speed_scale = 1.0
	# Pas de glissade : le cycle de pas avance à la distance parcourue.
	animation.advance(parcouru / foulee if bouge else delta)


## Sifflet (main droite à la bouche) et bras tendu, entrée et sortie en 0,25 s.
func _signaler(delta: float) -> void:
	if rig == null:
		return
	if signal_bras != _signal_vu and _poids > 0.0:
		_poids = move_toward(_poids, 0.0, delta / 0.25)
	else:
		_signal_vu = signal_bras
		_poids = move_toward(_poids, 1.0 if not signal_bras.is_empty() else 0.0, delta / 0.25)
	if _signal_vu.is_empty() or _poids <= 0.0:
		return
	var w := smoothstep(0.0, 1.0, _poids)
	var repere := global_basis
	if _signal_vu == "sifflet":
		Presentation._solve_arm(rig, "R", global_position + repere * Vector3(-0.04, 1.68, 0.16), global_position + repere * Vector3(-0.7, 1.0, -0.4), w)
		return
	# Bras tendu : le plus proche de la direction voulue (gauche ou droite du corps).
	var d := Vector3(direction_bras.x, 0.0, direction_bras.z)
	if d.length() < 0.01:
		return
	d = d.normalized()
	var gauche := repere.x.dot(d) >= 0.0
	var epaule := global_position + repere * Vector3(0.2 if gauche else -0.2, 1.55, 0.0)
	if _signal_vu == "coude":
		# Bras plié (coup franc) : bras à l'horizontale vers l'équipe, avant-bras levé, coude à 90°, depuis
		# l'épaule et avec les longueurs du squelette (le coude tombe ainsi à la hauteur de l'épaule).
		# Le pôle (direction, comme pour le solveur) pousse le coude vers l'équipe et un peu vers le bas.
		var cote := "L" if gauche else "R"
		var os_bras := rig.find_bone("UpperArm." + cote)
		var os_avant := rig.find_bone("LowerArm." + cote)
		var os_main := rig.find_bone("Palm." + cote)
		var bras := COUDE_BRAS
		var avant_bras := COUDE_AVANT_BRAS
		if mini(os_bras, mini(os_avant, os_main)) >= 0:
			var a := rig.to_global(rig.get_bone_global_pose(os_bras).origin)
			var b := rig.to_global(rig.get_bone_global_pose(os_avant).origin)
			var c := rig.to_global(rig.get_bone_global_pose(os_main).origin)
			epaule = a
			bras = a.distance_to(b)
			avant_bras = b.distance_to(c) * 0.97
		var coude := epaule + d * bras
		Presentation._solve_arm(rig, cote, coude + Vector3.UP * avant_bras, d * 1.0 + Vector3.DOWN * 0.15, w)
		return
	var main := epaule + (d * cos(hauteur_bras * 0.7) + Vector3.UP * sin(hauteur_bras * 0.7)) * 0.62
	Presentation._solve_arm(rig, "L" if gauche else "R", main, epaule + Vector3.DOWN * 0.5 - d * 0.3, w)
