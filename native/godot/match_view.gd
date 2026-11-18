class_name NativeMatchView
extends Node3D
## Projection de présentation du moteur historique. Aucune règle ni physique ici.
## Adapter source : x 0..100 / y 0..70 -> x -50..50 / z -35..35.

const ATHLETE := "res://assets/match3d/quaternius-rugby-athlete.glb"
const BLEND_SECONDS := 0.55
const STADIUM_FONT := "res://fonts/BarlowCondensed-SemiBold.ttf"
const ClubPresentation = preload("res://ui/game_skin.gd")
const Presentation = preload("res://match_presentation.gd")
const Motion = preload("res://match_motion.gd")
const Kit = preload("res://match_kit.gd")
const Athlete = preload("res://match_athlete.gd")
const Contact = preload("res://match_contact.gd")
const Cut = preload("res://match_cut.gd")
const Pass = preload("res://match_pass.gd")
const Gestes = preload("res://match_gestes.gd")
const Rendu = preload("res://match_rendu.gd")
const Animations = preload("res://match_animations.gd")
const Choregraphie = preload("res://match_choregraphie.gd")
const Formations = preload("res://match_formations.gd")
const Impacts = preload("res://match_impacts.gd")
const Tactique = preload("res://match_tactique.gd")
const ApresEssai = preload("res://match_apres_essai.gd")
const CUT_SECONDS := 0.30
## Nombre de joueurs à l'image, chacun à plus de Motion.TRAJET_REPLACEMENT de sa place, à partir
## duquel la vue coupe pour les replacer (équipe qui se reforme) au lieu de les faire courir.
const REFORMATION_MIN := 6
## Caméras de retransmission (TV) et « au contact » (action), en perspective depuis le 18 novembre
## 2026 (orthographiques avant, TV à 41° et 42 à 64 m de champ). Seule la direction de ces décalages
## compte : la distance découle de la hauteur visible voulue au point visé et de l'angle de champ.
## TV : plein travers, environ 28° au-dessus de l'horizon, comme la caméra principale d'une tribune ;
## action : plus près, plus ouverte, un peu de biais.
const TV_OFFSET := Vector3(0.0, 0.47, 0.883)
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
## Poteaux de but (montants en x = ±POTEAUX_X, z = ±POTEAUX_Z, hauts de POTEAU_HAUT m, barre à
## BARRE_Y m) : la caméra au contact pivote autour du point visé (jusqu'à CONTOURNEMENT_MAX rad, par
## pas de CONTOURNEMENT_PAS) quand un montant ou la barre, élargi de POTEAU_MARGE m, passe entre elle
## et l'action. Le pivot est amorti (pas d'à-coup) et revient à zéro dès que la vue est dégagée.
const POTEAUX_X := 50.0
const POTEAUX_Z := 2.8
const POTEAU_HAUT := 12.0
const BARRE_Y := 3.0
const POTEAU_MARGE := 0.6
const CONTOURNEMENT_MAX := 0.7
const CONTOURNEMENT_PAS := 0.05
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
## Hauteur visible (m) au point visé de la caméra de base (hors temps fort). Le cadrage des temps
## forts (match_cadrage.gd) la règle ensuite selon les joueurs utiles.
const TV_TAILLE := 30.0
const ACTION_TAILLE := 16.0
## Mi-temps et fin de match : plan large de tout le terrain, vu de haut au-dessus de la tribune
## proche (rayons au-dessus de son toit) : direction, point visé, recul (m) et angle de champ.
const PLAN_LARGE_OFFSET := Vector3(0.0, 0.64, 0.77)
const PLAN_LARGE_VISE := Vector3(0.0, 0.0, 4.0)
const PLAN_LARGE_RECUL := 125.0
const PLAN_LARGE_CHAMP := 36.0
## Grands moments (18 novembre 2026) : à la mi-temps et en fin de match, sous le plan large, les
## joueurs rentrent en marchant vers le tunnel, au milieu de la touche proche (sous la tribune
## principale). Allure de marche (m/s) : sous le seuil du trot des clips (2,5 m/s).
const TUNNEL := Vector3(0.0, 0.0, 40.0)
## 18/11/2026 (soir) : sous le plan large, les joueurs minuscules ne faisaient que 8 m loin du tunnel.
## La sortie montrée part d'une coupe : chaque joueur reprend, dans la même direction depuis le
## tunnel, à SORTIE_PROCHE_MIN à SORTIE_PROCHE_MAX m de lui (jamais au-delà de SORTIE_PROCHE_Z, dans
## le terrain), puis rentre en marche rapide, trot léger (sous le seuil de course des clips, 2,5 m/s).
const ALLURE_SORTIE := 2.4
const SORTIE_PROCHE_MIN := 4.5
const SORTIE_PROCHE_MAX := 10.0
const SORTIE_PROCHE_Z := 34.0
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
const STADIUM_EVENING_SCRIPT := "res://match_stadium_evening.gd"
var _players: Node3D
var _ball: Node3D
var _camera: Camera3D
var _athlete_scene: PackedScene
## Animations de déplacement adaptées : absentes sans CD_MATCH_ANIMATIONS.
var _animations_adaptees: RefCounted
var _actors: Dictionary = {}
var _team_colors: Array[Color] = [Color("d43e47"), Color("6f9ac9")]
var _kits: Array[Dictionary] = []
var _camera_focus := Vector3.ZERO
var _camera_framed := false
var _camera_cut := true
var _ball_from := Vector3.ZERO
var _ball_from_basis := Basis.IDENTITY
var _ball_target := Vector3.ZERO
var _camera_mode := "tv"
## Point visé final de la caméra suivie (après cadrage, gestes et bornes du terrain).
var _camera_look := Vector3.ZERO
## Mi-temps ou fin de match : plan large du terrain (annoncé par l'image du direct, ou par la
## régie des temps forts une fois le dernier temps fort fini).
var _plan_large := false
var _plan_large_direct := false
var _plan_large_regie := false
## Décalage amorti du recentrage borné, et sa vitesse.
var _borne := Vector3.ZERO
var _borne_vitesse := Vector3.ZERO
var _paused := false
var _pending: Dictionary = {}
var _has_pending := false
var _venue_batches: Dictionary = {}
var _carrier_id := ""
var _kind := ""
var _quality := "balanced"
var _sun: DirectionalLight3D
var _ball_marker: Node3D
var _ball_beacon: Node3D
var _ball_attached := false
var _ball_travel := 1.0
var _grass: ShaderMaterial
var _contact_plan: Dictionary = {}
var _action_key := ""
var _action_motion := true
var _pass_plan: Dictionary = {}
var _pass_elapsed := 0.0
var _live_cadence := 1
var _stadium_evening := false
var _stadium_kit: Node3D
var _club_identity_key := ""
var _club_crest: Texture2D
var _club_branding: MultiMeshInstance3D
## Gestes de rugby (touche, ballon porté, essai) : posés par le match en temps forts (repli CD_MATCH_GESTES=0) ou par CD_MATCH_GESTES=1 dans le direct d'origine.
var _gestes: RefCounted
## Sans les gestes complets, la touche reste jouée (lancer du talonneur, saut porté) : la même
## mise en scène de match_gestes.gd, réduite à la touche (18/11/2026).
var _touche_directe: RefCounted = Gestes.new(self, true)
## Pistes du chorégraphe de temps forts (CD_MATCH_CHOREGRAPHE=1) : la vue les suit à la place de son interpolation.
var _choregraphie: RefCounted
## Formations des phases arrêtées (mêlée liée, alignement de touche) : toujours actives.
var _formations: RefCounted
var _cadrage: RefCounted
## Pivot de contournement des poteaux (caméra au contact), en radians, et sa vitesse amortie.
var _contournement := 0.0
var _contournement_vitesse := 0.0
# Rendu moderne (Forward+ seulement, voir match_rendu.gd) ; null sous gl_compatibility.
var _rendu: RefCounted
var _ground_meshes: Array[MeshInstance3D] = []
## Poses tenues après une liaison (mêlée liée) : id -> {pitch, lift, poids, base, lache}.
var _tenues: Dictionary = {}
var _tenue_cle := ""
## Plaquage, ruck et joie d'essai avec les clips du modèle (match_impacts.gd).
var _impacts: RefCounted = Impacts.new(self)
## Compteurs de contrôle (tests, capture) : joueurs replacés au lieu de courir, et coupes posées pour cela.
var replacements := 0
var replacements_coupes := 0
## Ralenti de présentation (essai aplati, posé par la régie) : facteur appliqué au temps de la vue,
## 1 hors ralenti. Les joueurs, le ballon, les gestes et la caméra ralentissent ensemble.
var ralenti := 1.0
## Sortie des joueurs en cours (mi-temps, fin de match) : jusqu'à la prochaine image du moteur.
var sortie := false
## Sortie montrée de près (joueurs rapprochés du tunnel, plan qui suit le groupe) et point visé.
var plan_sortie := false
var _sortie_vise := Vector3.ZERO


func set_club_identity(club: Dictionary) -> void:
	var identity: Dictionary = ClubPresentation.identity(club)
	var key := JSON.stringify([identity.get("logoPath", club.get("logoPath", "")), identity.get("slug", "")])
	if key == _club_identity_key:
		return
	_club_identity_key = key
	# Exactly the same active pack priority as the UI. Its initials fallback is
	# deliberately left off the physical surfaces when no texture is available.
	var crest_control: Control = ClubPresentation.crest(club, 256)
	_club_crest = crest_control.texture if crest_control is TextureRect else null
	crest_control.free()
	if is_instance_valid(_club_branding):
		_update_club_branding()


func _ready() -> void:
	name = "NativeMatchView"
	_athlete_scene = load(ATHLETE) as PackedScene
	if Animations.demande():
		var adaptees := Animations.new()
		if adaptees.charger():
			_animations_adaptees = adaptees
	if OS.get_environment("CD_MATCH_GESTES") == "1":
		set_gestes(true)
	_formations = Formations.new(self)
	_refresh_kits()
	_build_environment()
	_build_ground()
	_build_stadium()
	_flush_venue_boxes()
	_players = Node3D.new()
	_players.name = "Players"
	add_child(_players)
	_build_ball()
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.5
	_camera.far = 500.0
	add_child(_camera)
	_camera.current = true
	if Rendu.actif():
		_rendu = Rendu.new(self)
	set_camera(_camera_mode)
	set_quality(_quality)
	set_stadium_evening(_stadium_evening)
	if _has_pending:
		apply_frame(_pending)
		_pending = {}
		_has_pending = false


func set_stadium_evening(enabled: bool) -> void:
	_stadium_evening = enabled
	if not is_node_ready():
		return
	if enabled and not is_instance_valid(_stadium_kit):
		_stadium_kit = load(STADIUM_EVENING_SCRIPT).new()
		_stadium_kit.attach(self)
	if is_instance_valid(_stadium_kit):
		_stadium_kit.set_evening(enabled)
	if _rendu:
		_rendu.appliquer()


## Cadrage des temps forts : posé par la régie du match en temps forts, absent dans le direct d'origine.
func set_cadrage(value: RefCounted) -> void:
	_cadrage = value


func set_gestes(enabled: bool) -> void:
	if enabled == (_gestes != null):
		return
	if _gestes:
		_gestes.cancel()
	_touche_directe.cancel()
	_gestes = Gestes.new(self) if enabled else null


## Gestes qui mettent des joueurs en scène : les gestes complets, sinon la touche du direct.
func mise_en_scene() -> RefCounted:
	return _gestes if _gestes != null else _touche_directe


func set_action_motion(enabled: bool) -> void:
	if enabled == _action_motion:
		return
	_action_motion = enabled
	if not enabled:
		_stop_live_pass()
		for entry: Dictionary in _actors.values():
			entry.cut_direction = 0
			entry.cut_beat = -1.0
			entry.cut_plant.clear()


## Geste adapté (bibliothèque CD_MATCH_ANIMATIONS) joué une fois sur un joueur, à la
## place de son déplacement : de `debut` à `fin` secondes du clip (fin négative : jusqu'au
## bout), puis `suite` s'il y en a une, puis retour au déplacement. `ancre` : le joueur
## reste où il est pendant le geste (chute, relevé), puis rejoint sa place de la scène.
## Rend faux sans bibliothèque ou sans ce clip : l'appelant garde sa pose procédurale.
func jouer_geste(id: String, nom: String, debut: float = 0.0, fin: float = -1.0, ancre: bool = false, suite: Array = []) -> bool:
	if _animations_adaptees == null or not _actors.has(id) or not _actors[id].adapted or _paused:
		return false
	var clip: StringName = _animations_adaptees.geste(nom)
	if clip.is_empty():
		return false
	var longueur: float = _animations_adaptees.duree(nom)
	var entry: Dictionary = _actors[id]
	entry.geste = {"nom": nom, "clip": clip, "t": clampf(debut, 0.0, longueur), "fin": longueur if fin < 0.0 else minf(fin, longueur),
		"ancre": ancre, "suite": suite.duplicate(), "lance": false}
	return true


## Vrai pendant un geste adapté (le geste procédural correspondant ne s'applique pas).
func geste_adapte(id: String, nom: String = "") -> bool:
	if not _actors.has(id):
		return false
	var en_cours: Dictionary = _actors[id].get("geste", {})
	return not en_cours.is_empty() and (nom.is_empty() or str(en_cours.nom) == nom)


## Instant clé d'un geste adapté dans son clip (0 sans bibliothèque).
func instant_geste(nom: String) -> float:
	return _animations_adaptees.instant_cle(nom) if _animations_adaptees != null else 0.0


## Clip du modèle d'origine (« Man_Jump », « Man_Death », « Man_Clapping »…) joué une fois sur
## un joueur, comme un geste adapté : de `debut` à `fin` secondes du clip (fin négative : jusqu'au
## bout), à `vitesse`. Sans bibliothèque adaptée. Rend faux sans ce clip dans le modèle.
func jouer_clip_natif(id: String, suffixe: String, debut: float = 0.0, fin: float = -1.0, ancre: bool = false, vitesse: float = 1.0) -> bool:
	if not _actors.has(id) or _paused:
		return false
	var animation: AnimationPlayer = _actors[id].animation
	if animation == null:
		return false
	for clip: StringName in animation.get_animation_list():
		if str(clip).ends_with(suffixe):
			var longueur := animation.get_animation(clip).length
			_actors[id].geste = {"nom": suffixe, "clip": clip, "t": clampf(debut, 0.0, longueur), "fin": longueur if fin < 0.0 else minf(fin, longueur),
				"ancre": ancre, "suite": [], "lance": false, "vitesse": maxf(vitesse, 0.05)}
			return true
	return false


func arreter_geste(id: String) -> void:
	if _actors.has(id):
		_actors[id].geste = {}


## Durée du trajet du ballon vers sa nouvelle place (s) : un tir au but vole plus longtemps
## qu'une transition ordinaire (BLEND_SECONDS), le temps de le suivre jusqu'aux perches.
func duree_vol() -> float:
	if _tir_au_but():
		return ApresEssai.duree_vol(_ball_from, _ball_target)
	return BLEND_SECONDS


## Ballon d'un tir au but en route vers la ligne de but visée (pas la pose « prêt » sur la marque).
func _tir_au_but() -> bool:
	return _kind in ["goal", "miss"] and _carrier_id.is_empty() and absf(_ball_target.x) >= 49.0


## Suit les pistes du chorégraphe (moteur Node) : positions, caps et états des joueurs,
## ballon. Rend faux sans pistes valides : la vue garde alors son interpolation.
## `vitesse` : facteur de lecture (la régie accélère les temps forts dans les tests).
func jouer_choregraphie(pistes: Dictionary, vitesse: float = 1.0) -> bool:
	if not is_node_ready():
		return false
	if _choregraphie == null:
		_choregraphie = Choregraphie.new(self)
	_stop_live_pass()
	_pass_plan = {}
	_contact_plan = {}
	_impacts.annuler()
	mise_en_scene().cancel()
	if not _choregraphie.charger(pistes):
		return false
	_choregraphie.vitesse = vitesse
	_paused = false
	_ball.visible = true
	for entry: Dictionary in _actors.values():
		entry.geste = {}
	return true


func choregraphie_active() -> bool:
	return _choregraphie != null and _choregraphie.actif


func choregraphie_temps() -> float:
	return _choregraphie.temps if choregraphie_active() else 0.0


func choregraphie_finie() -> bool:
	return choregraphie_active() and _choregraphie.finie()


func figer_choregraphie(fige: bool) -> void:
	if choregraphie_active():
		_choregraphie.fige = fige
		_paused = fige


## Poses tenues après une liaison (match_liaison.gd) : les avants liés d'une mêlée restent
## penchés pendant le plan de la mêlée, puis se relèvent en 0,35 s au fait suivant.
func tenir_poses(poses: Dictionary) -> void:
	for id: String in poses:
		if not _actors.has(id) or not poses[id] is Array or (poses[id] as Array).size() < 2:
			continue
		var model: Node3D = _actors[id].model
		_tenues[id] = {"pitch": float(poses[id][0]), "lift": float(poses[id][1]), "poids": 1.0, "base": model.transform, "lache": false}
	_tenue_cle = _action_key


func _poser_tenues(delta: float) -> void:
	for id: String in _tenues.keys():
		var tenue: Dictionary = _tenues[id]
		if not _actors.has(id) or (_choregraphie != null and _choregraphie.stages(id)):
			_tenues.erase(id)
			continue
		var model: Node3D = _actors[id].model
		if tenue.lache and not _paused:
			tenue.poids = maxf(0.0, float(tenue.poids) - delta / 0.35)
		model.transform = tenue.base
		var w := smoothstep(0.0, 1.0, float(tenue.poids))
		model.rotation.x = float(tenue.pitch) * w
		model.position.y += float(tenue.lift) * w
		if float(tenue.poids) <= 0.0:
			_tenues.erase(id)


## Fin des pistes : chaque joueur reste où il est et reprend l'interpolation de la vue.
func arreter_choregraphie() -> void:
	if not choregraphie_active():
		return
	_choregraphie.arreter()
	for entry: Dictionary in _actors.values():
		var at: Vector3 = (entry.node as Node3D).position
		entry.from = at
		entry.target = at
		entry.elapsed = BLEND_SECONDS
		entry.duree = BLEND_SECONDS
		entry.velocity = Vector3.ZERO
		entry.tangent = Vector3.ZERO
		entry.holding = false
		entry.geste = {}
	_ball_from = _ball.position
	_ball_target = _ball.position
	_ball_travel = 1.0
	_ball_attached = false
	_carrier_id = ""


func set_live_cadence(steps: int) -> void:
	_live_cadence = steps


## L'essai mis en scène par un geste (course ou ballon porté) est aplati à l'écran ; vrai sans
## geste d'essai (l'image du moteur est posée telle quelle). Sert à la régie pour légender et
## acclamer l'essai à l'instant où on le voit aplati (lot 8 : une scène d'essai n'a pas de porteur,
## l'ancien contrôle « porteur arrivé » était toujours vrai).
func essai_aplati() -> bool:
	return _gestes == null or not _gestes.active() or _gestes.essai_aplati()


func is_presenting_extended_pass() -> bool:
	return _pass_plan.get("duration", 0.0) == Pass.LIVE_SECONDS or mise_en_scene().holding_tick() or _impacts.tient()


func apply_frame(live: Dictionary) -> void:
	if not is_node_ready():
		_pending = live.duplicate(true)
		_has_pending = true
		return
	# Une nouvelle image venue de la régie ou du direct met fin aux pistes en cours (et à la sortie).
	arreter_choregraphie()
	if plan_sortie:
		_camera_cut = true
	sortie = false
	plan_sortie = false
	var scene: Dictionary = live.get("scene", {})
	if scene.is_empty() or not scene.get("players", null) is Array:
		_clear_presence()
		return
	var ball_data: Dictionary = scene.get("ball", {})
	var has_ball := ball_data.has("x") and ball_data.has("y")
	var previous_carrier := _carrier_id
	_carrier_id = Presentation.carrier_id(scene) if has_ball else ""
	var previous_kind := _kind
	_kind = str(scene.get("kind", ""))
	var teams: Array = live.get("teams", [])
	var colors_changed := false
	for side in mini(teams.size(), 2):
		var club: Dictionary = teams[side]
		var presentation: Dictionary = club.get("presentation", {})
		var color := Color.from_string(str(presentation.get("color", club.get("color", "#eeeeee"))), _team_colors[side])
		if color != _team_colors[side]:
			_team_colors[side] = color
			colors_changed = true
	if colors_changed:
		# A home-colour change can also change the away contrast decision.
		_refresh_kits()
		Athlete.clear_palette()
		for entry: Dictionary in _actors.values():
			_recolor(entry.model, entry.side)
			Tactique.colorer(entry.node, _kits[entry.side].marker)
	_paused = live.get("paused", false) or live.get("finished", false) or live.get("atBreak", false)
	_plan_large_direct = bool(live.get("finished", false)) or bool(live.get("atBreak", false))
	_maj_plan_large()
	var key := str(scene.get("key", ""))
	# Pose tenue d'une liaison (mêlée liée) : relâchée au fait suivant (le ballon sort).
	if not _tenues.is_empty() and key != _tenue_cle:
		for tenue: Dictionary in _tenues.values():
			tenue.lache = true
	var new_action := key != _action_key
	# Plaqueur et ruck : placés à leur place de contact dans la scène projetée.
	scene = _impacts.observer(scene, new_action, _action_motion and not _paused and has_ball and _live_cadence == 1)
	# Mêlée, sortie de mêlée, touche : places et postures de la phase (match_formations.gd).
	_formations.preparer(scene, new_action)
	var play_action := (_action_motion and not _paused and has_ball and _ball.visible
		and not _action_key.is_empty() and not key.is_empty())
	_action_key = key
	if not play_action or new_action:
		_stop_live_pass()
		_pass_plan = Pass.plan(scene) if play_action and _kind == "carry" else {}
		_pass_elapsed = 0.0
	_contact_plan = Contact.plan(scene) if not _paused and has_ball else {}
	var cut_allowed := (_action_motion and not _paused and _kind == "carry" and has_ball
		and _contact_plan.is_empty() and _pass_plan.is_empty())
	var carry_cut := cut_allowed and _ball_attached and _carrier_id == previous_carrier
	var declared_cut: Variant = scene.get("cut")
	var cut_side := 0
	if cut_allowed and play_action and new_action and declared_cut is Dictionary:
		var side: Variant = declared_cut.get("side")
		if declared_cut.get("carrier") == _carrier_id and (side is float or side is int) and absf(float(side)) == 1.0:
			cut_side = int(side)
	var present: Dictionary = {}
	for player: Dictionary in scene.players:
		var id := str(player.get("id", ""))
		var side := int(player.get("side", -1))
		if id.is_empty() or side not in [0, 1] or present.size() >= 30:
			continue
		present[id] = true
		var target: Vector3 = _formations.place(id, _world(player))
		if not _actors.has(id):
			_actors[id] = _make_actor(id, side, target)
			Tactique.poser_repere(_actors[id].node, player, _kits[side].marker)
		var entry: Dictionary = _actors[id]
		entry.holding = id == _carrier_id
		var can_cut: bool = carry_cut and entry.holding
		if not cut_allowed or not entry.holding or new_action:
			if entry.cut_beat >= 0.0:
				entry.cut_direction = 0
				entry.cut_plant.clear()
			entry.cut_beat = -1.0
		if not can_cut and entry.cut_beat < 0.0:
			entry.cut_direction = 0
			entry.cut_plant.clear()
		# A UI refresh is not a new sporting movement. Keep its current curve.
		if not (entry.target as Vector3).is_equal_approx(target):
			var incoming: Vector3 = entry.velocity
			if can_cut and incoming.is_zero_approx() and entry.cut_idle <= 0.3:
				incoming = (entry.target - entry.from) / float(entry.duree)
			if entry.cut_beat < 0.0:
				entry.cut_direction = Cut.direction(incoming, target - entry.node.position, BLEND_SECONDS) if can_cut else 0
				entry.cut_plant.clear()
			entry.cut_idle = 0.0
			entry.from = entry.node.position
			entry.target = target
			# Durée selon la distance : personne ne court plus vite qu'un sprint (Motion.ALLURE_MAX).
			entry.duree = Motion.duree(entry.from, target)
			entry.tangent = Motion.tangent(entry.velocity, target - entry.node.position, entry.duree)
			entry.elapsed = 0.0
		if entry.holding and cut_side != 0:
			entry.cut_direction = cut_side
			entry.cut_beat = 0.0
			entry.cut_normal_speed = _live_cadence == 1
			entry.cut_plant.clear()
		if _paused:
			entry.node.position = target
			entry.from = target
			entry.velocity = Vector3.ZERO
			entry.tangent = Vector3.ZERO
			entry.elapsed = BLEND_SECONDS
			entry.duree = BLEND_SECONDS
			entry.cut_idle = BLEND_SECONDS
			entry.feet.clear()
			entry.grip = 1.0 if entry.holding else 0.0
		if entry.side != side:
			entry.side = side
			_recolor(entry.model, side)
	for id: String in _actors.keys():
		if not present.has(id):
			var actor: Node3D = _actors[id].node
			_players.remove_child(actor)
			actor.queue_free()
			_actors.erase(id)
	if not _pass_plan.is_empty():
		if new_action:
			_stage_live_pass()
		elif not _actors.has(_pass_plan.passer) or not _actors.has(_pass_plan.receiver):
			_stop_live_pass()
	if has_ball:
		var next_target := _world(ball_data, 0.23)
		var ball_changed := not _ball_target.is_equal_approx(next_target) or previous_carrier != _carrier_id
		# Ballon qui réapparaît près du point visé : la caméra glisse jusqu'à lui ; loin, elle coupe.
		if not _ball.visible and Vector2(next_target.x - _camera_focus.x, next_target.z - _camera_focus.z).length() > RETARD_MAX * (ACTION_TAILLE if _camera_mode == "action" else TV_TAILLE):
			_camera_cut = true
		# The first snapshot is a pose, not an invented pass from ground level.
		_ball_attached = (_pass_plan.is_empty() and not _carrier_id.is_empty()
			and (not _ball.visible or _paused or cut_side != 0 or (previous_carrier == _carrier_id and _ball_attached)))
		var continuing_reception := not _carrier_id.is_empty() and previous_carrier == _carrier_id and not _ball_attached
		if (ball_changed and not continuing_reception) or not _ball.visible:
			_ball_from = _ball.position if _ball.visible else next_target
			_ball_from_basis = _ball.global_basis
			_ball_target = next_target
			_ball_travel = 1.0 if _paused else 0.0
		if _paused:
			_ball_travel = 1.0
		_ball.visible = true
	else:
		# Ballon absent de la scène : la caméra reste où elle est (pas de saut au centre du terrain).
		_ball.visible = false
		_ball_attached = false
	mise_en_scene().observe(live, scene, new_action, _action_motion and not _paused and has_ball and _live_cadence == 1)
	if new_action and play_action and _animations_adaptees != null and _live_cadence == 1:
		_gestes_du_fait(scene, previous_kind)
	_replacer_longs(new_action)


## Très grands déplacements (replacement après un essai, équipe qui se reforme, poursuivants
## d'un long coup de pied) : plutôt qu'une course de plus de Motion.TRAJET_REPLACEMENT mètres, le
## joueur est replacé à quelques pas de sa place. Quand au moins REFORMATION_MIN de ces joueurs
## sont à l'image au début d'une nouvelle action, la caméra coupe et tous sont replacés pendant la
## coupe ; sinon seuls ceux qui ne sont pas à l'image le sont (les autres courent au sprint).
func _replacer_longs(new_action: bool) -> void:
	if _paused:
		return
	var longs: Array[String] = []
	var visibles := 0
	for id: String in _actors:
		var entry: Dictionary = _actors[id]
		# Seulement un trajet qui vient d'être fixé, et jamais un joueur mis en scène ailleurs.
		if float(entry.elapsed) > 0.0 or _is_pass_player(id) or mise_en_scene().stages(id) or (_choregraphie != null and _choregraphie.stages(id)) or _impacts.occupe(id):
			continue
		var at: Vector3 = (entry.node as Node3D).position
		var target: Vector3 = entry.target
		if Vector2(target.x - at.x, target.z - at.z).length() <= Motion.TRAJET_REPLACEMENT:
			continue
		longs.append(id)
		if _a_l_image(at) or _a_l_image(target):
			visibles += 1
	if longs.is_empty():
		return
	var coupe := new_action and visibles >= REFORMATION_MIN
	for id: String in longs:
		var entry: Dictionary = _actors[id]
		if not coupe and (entry.holding or _a_l_image((entry.node as Node3D).position) or _a_l_image(entry.target)):
			continue
		_replacer(entry)
	if coupe:
		_camera_cut = true
		# Le ballon est déjà où l'action reprend.
		_ball_from = _ball_target
		_ball_travel = 1.0
		replacements_coupes += 1


func _replacer(entry: Dictionary) -> void:
	var actor: Node3D = entry.node
	var target: Vector3 = entry.target
	var gap := Vector3(target.x - actor.position.x, 0.0, target.z - actor.position.z)
	var pas := minf(Motion.DERNIERS_PAS, gap.length())
	actor.position = target - gap.normalized() * pas if gap.length() > 0.01 else target
	if gap.length() > 0.01:
		actor.rotation.y = atan2(gap.x, gap.z)
	entry.from = actor.position
	entry.velocity = Vector3.ZERO
	entry.tangent = Vector3.ZERO
	entry.duree = Motion.duree(entry.from, target)
	entry.elapsed = 0.0
	entry.feet.clear()
	replacements += 1


func _a_l_image(point: Vector3) -> bool:
	return is_instance_valid(_camera) and _camera.is_inside_tree() and _camera.is_position_in_frustum(point + Vector3(0.0, 1.0, 0.0))


## Temps (s) qu'il faut encore aux joueurs proches du ballon pour finir leur déplacement à
## l'écran : la régie ne passe pas à l'action suivante avant (avec une échéance).
func deplacement_restant(rayon: float = 25.0) -> float:
	var reste := 0.0
	var ballon := Vector2(_ball_target.x, _ball_target.z)
	for id: String in _actors:
		var entry: Dictionary = _actors[id]
		if _is_pass_player(id) or mise_en_scene().stages(id) or (_choregraphie != null and _choregraphie.stages(id)) or _impacts.occupe(id):
			continue
		var target: Vector3 = entry.target
		if Vector2(target.x, target.z).distance_to(ballon) > rayon:
			continue
		reste = maxf(reste, float(entry.duree) - float(entry.elapsed))
	return reste


## Gestes adaptés déclenchés par le fait affiché (bibliothèque CD_MATCH_ANIMATIONS
## seulement) : le joueur que le moteur met en avant frappe ou reçoit le ballon.
## Le clip est calé pour que le contact du pied ou la prise tombe au départ ou à
## l'arrivée du ballon. Sans le clip, rien ne change.
func _gestes_du_fait(scene: Dictionary, previous_kind: String) -> void:
	var kind := str(scene.get("kind", ""))
	var possession := int(scene.get("possession", -1))
	var featured := ""
	for player: Dictionary in scene.get("players", []):
		if player.get("featured", false) and int(player.get("side", -1)) == possession:
			featured = str(player.get("id", ""))
	if featured.is_empty() or not _actors.has(featured) or mise_en_scene().stages(featured):
		return
	var ball: Dictionary = scene.get("ball", {})
	var origin: Variant = scene.get("origin")
	match kind:
		"goal", "miss", "kick":
			# Pénalité, transformation, jeu au pied : le pied frappe quand le ballon part.
			var cle := instant_geste("coup_de_pied")
			jouer_geste(featured, "coup_de_pied", maxf(0.0, cle - 0.1), -1.0, true)
		"kickoff", "drop22", "goalLine":
			# Renvoi en drop : seulement si le moteur place le botteur au ballon.
			var at: Dictionary = origin if origin is Dictionary else ball
			var spot := _world(at)
			if (_actors[featured].node as Node3D).position.distance_to(Vector3(spot.x, 0.0, spot.z)) < 3.0:
				jouer_geste(featured, "drop", maxf(0.0, instant_geste("drop") - 0.1), -1.0, true)
		"reception":
			# Ballon haut après un jeu au pied : prise bras tendus ; sinon prise à hauteur de poitrine.
			# Le clip s'arrête juste après la prise (la suite d'origine est une chute).
			var nom := "reception_haute" if previous_kind in ["kick", "kickoff", "drop22", "goalLine", "touch"] else "reception"
			var cle := instant_geste(nom)
			jouer_geste(featured, nom, maxf(0.0, cle - 0.5), cle + 0.3)


## Régie des temps forts : mi-temps ou fin de match, plus rien à rejouer.
func set_plan_large(on: bool) -> void:
	_plan_large_regie = on
	_maj_plan_large()


func _maj_plan_large() -> void:
	var large := _plan_large_direct or _plan_large_regie
	if large != _plan_large:
		_plan_large = large
		_camera_cut = true


func plan_large() -> bool:
	return _plan_large


## Ralenti de présentation posé par la régie (essai) : 1 rend la vitesse réelle.
func set_ralenti(facteur: float) -> void:
	ralenti = clampf(facteur, 0.05, 1.0) if is_finite(facteur) else 1.0


## Mi-temps, fin de match (régie des temps forts) : chaque joueur quitte sa place et marche vers
## le tunnel, à ALLURE_SORTIE ; le ballon est laissé au sol. Plus rien d'une action en cours (passe,
## contact, geste, posture de mêlée) ne reste posé. La prochaine image du moteur reprend la main.
## `rapprocher` : coupe sur la sortie montrée de près (plan_sortie) ; chaque joueur repart plus près
## du tunnel (place_proche_du_tunnel), et la caméra suit le groupe jusqu'à l'entrée du tunnel.
func sortir_du_terrain(rapprocher: bool = false) -> void:
	if not is_node_ready():
		return
	arreter_choregraphie()
	_stop_live_pass()
	_pass_plan = {}
	_contact_plan = {}
	_impacts.annuler()
	mise_en_scene().cancel()
	_formations.preparer({}, true)
	for tenue: Dictionary in _tenues.values():
		tenue.lache = true
	_paused = false
	sortie = true
	_kind = ""
	_carrier_id = ""
	_ball_attached = false
	if _ball.visible:
		_ball_from = _ball.position
		_ball_from_basis = _ball.global_basis
		_ball_target = Vector3(_ball.position.x, Impacts.BALLON_AU_SOL, _ball.position.z)
		_ball_travel = 0.0
	plan_sortie = rapprocher
	if rapprocher:
		_camera_cut = true
	for id: String in _actors:
		var entry: Dictionary = _actors[id]
		var actor: Node3D = entry.node
		var at: Vector3 = actor.position
		var but := place_de_sortie(at, int(entry.side))
		if rapprocher:
			# Coupe : le joueur reparaît plus près du tunnel, déjà tourné vers lui.
			at = place_proche_du_tunnel(at)
			actor.position = at
			actor.rotation.y = atan2(but.x - at.x, but.z - at.z)
		entry.holding = false
		entry.geste = {}
		entry.grip = 0.0
		entry.cut_direction = 0
		entry.cut_beat = -1.0
		entry.cut_plant.clear()
		entry.from = at
		entry.target = but
		entry.duree = maxf(Motion.DUREE_MIN, Vector2(but.x - at.x, but.z - at.z).length() / ALLURE_SORTIE)
		entry.elapsed = 0.0
		entry.tangent = Vector3.ZERO
		entry.velocity = Vector3.ZERO
		entry.feet.clear()


## Point d'arrivée de la marche vers le tunnel : chaque camp sur sa moitié de l'entrée, les joueurs
## étalés sur quelques mètres pour ne pas converger tous sur le même point.
static func place_de_sortie(depuis: Vector3, camp: int) -> Vector3:
	var cote := -1.0 if camp == 0 else 1.0
	return TUNNEL + Vector3(cote * (1.0 + fposmod(depuis.x * 0.37 + depuis.z * 0.21, 3.0)), 0.0, 0.0)


## Départ de la sortie montrée de près : dans la direction du joueur vue du tunnel, à une distance
## ramenée entre SORTIE_PROCHE_MIN et SORTIE_PROCHE_MAX m (l'ordre des distances est gardé : les plus
## loin restent derrière), et jamais hors du terrain côté tunnel.
static func place_proche_du_tunnel(depuis: Vector3) -> Vector3:
	var ecart := Vector2(depuis.x - TUNNEL.x, depuis.z - TUNNEL.z)
	var loin := ecart.length()
	var direction := ecart / loin if loin > 0.01 else Vector2(0.0, -1.0)
	# Toujours vers le terrain (z décroissant depuis le tunnel).
	if direction.y > -0.35:
		direction = Vector2(signf(direction.x) if absf(direction.x) > 0.001 else 1.0, -0.35 / 0.937).normalized()
	var rayon := lerpf(SORTIE_PROCHE_MIN, SORTIE_PROCHE_MAX, clampf((loin - 5.0) / 60.0, 0.0, 1.0))
	var p := Vector2(TUNNEL.x, TUNNEL.z) + direction * rayon
	return Vector3(p.x, 0.0, minf(p.y, SORTIE_PROCHE_Z))


## Point visé du plan de sortie : le groupe des joueurs, tiré vers le tunnel où il se dirige.
func _vise_sortie() -> Vector3:
	var somme := Vector3.ZERO
	for entry: Dictionary in _actors.values():
		somme += (entry.node as Node3D).position
	var groupe := somme / maxf(1.0, float(_actors.size())) if not _actors.is_empty() else TUNNEL
	var vise := groupe.lerp(TUNNEL, 0.3)
	return Vector3(vise.x, 1.0, vise.z)


func set_camera(mode: String) -> void:
	var selected := mode if mode in ["tactical", "action"] else "tv"
	var changed := selected != _camera_mode
	_camera_mode = selected
	if is_instance_valid(_camera) and (changed or not _camera_framed):
		_fit_camera(0.0, true)
	if _rendu:
		_rendu.appliquer()


func _process(delta: float) -> void:
	# Ralenti de l'essai : tout ce que la vue anime avance moins vite (présentation seule).
	delta *= ralenti
	if not _pass_plan.is_empty():
		_pass_elapsed = minf(_pass_plan.duration, _pass_elapsed + delta)
	var preparation := smoothstep(0.0, Pass.PREP_SECONDS, _pass_elapsed)
	mise_en_scene().advance(delta)
	if choregraphie_active():
		_choregraphie.avancer(delta)
	if _formations:
		_formations.avancer(delta)
	for id: String in _actors:
		var entry: Dictionary = _actors[id]
		var actor: Node3D = entry.node
		var suivi: bool = _choregraphie != null and _choregraphie.stages(id)
		var staged: bool = suivi or mise_en_scene().stages(id)
		# Postures rendues dans l'ordre inverse de leur pose : formation (posée en dernier), puis gestes.
		if _formations:
			_formations.restaurer(id, entry)
		mise_en_scene().restore(id, entry)
		if entry.rig:
			Presentation.restore_contact(entry.rig, entry.contact_base)
			Cut.restore(entry.rig, entry.cut_pose)
		var previous := actor.position
		var previous_heading := actor.rotation.y
		var in_pass := _is_pass_player(id)
		if in_pass:
			var staging: Dictionary = _pass_plan.staging[id]
			actor.position = (staging.from as Vector3).lerp(staging.mark, preparation)
			actor.rotation.y = lerp_angle(staging.heading, staging.facing, preparation)
		elif suivi:
			_choregraphie.place(id, actor)
		elif staged:
			mise_en_scene().place(id, actor)
		else:
			# Temps passé à l'arrêt, une fois la place atteinte (même au milieu de cette image).
			var repos := float(entry.elapsed) + delta - float(entry.duree)
			if repos > 0.0:
				entry.cut_idle = minf(BLEND_SECONDS, entry.cut_idle + minf(delta, repos))
			entry.elapsed = minf(float(entry.duree), float(entry.elapsed) + delta)
		var progress: float = entry.elapsed / float(entry.duree)
		var live_cut: bool = entry.cut_beat >= 0.0 and entry.cut_normal_speed
		var oneshot: Dictionary = entry.get("geste", {})
		if not in_pass and not staged and not oneshot.is_empty() and oneshot.ancre:
			# Geste au sol ou sur place : le joueur reste où il est ; il rejoindra sa place ensuite.
			entry.from = actor.position
			entry.elapsed = 0.0
			entry.duree = Motion.duree(actor.position, entry.target)
			entry.velocity = Vector3.ZERO
			entry.tangent = Vector3.ZERO
		elif not in_pass and not staged:
			var travel := Cut.live_travel(progress) if live_cut else progress
			actor.position = Motion.position_at(entry.from, entry.target, entry.tangent, travel)
			entry.velocity = ((actor.position - previous) / maxf(delta, 0.001) if live_cut
				else Motion.velocity_at(entry.from, entry.target, entry.tangent, progress, entry.duree))
		var movement := actor.position - previous
		var speed := movement.length() / maxf(delta, 0.001)
		# Allure lissée : elle décide du port du ballon (deux mains ou sous le bras).
		if delta > 0.0 and not _paused:
			entry.allure = lerpf(float(entry.get("allure", 0.0)), minf(speed, 12.0), 1.0 - exp(-6.0 * delta))
		var moving := speed > 0.035 and not _paused
		if moving and not in_pass and not staged:
			var change := angle_difference(actor.rotation.y, atan2(movement.x, movement.z))
			actor.rotation.y += clampf(change, -7.2 * delta, 7.2 * delta)
		var animation: AnimationPlayer = entry.animation
		if animation and not oneshot.is_empty() and not _paused:
			# Geste adapté : le clip avance au temps, pas à la distance parcourue.
			if not oneshot.lance or animation.current_animation != oneshot.clip:
				oneshot.lance = true
				animation.play(oneshot.clip, 0.2)
				animation.seek(float(oneshot.t), false)
			animation.speed_scale = 1.0
			# « vitesse » (match_impacts.gd) : clip lu à une autre allure, ou à l'envers (relevé).
			var vitesse := float(oneshot.get("vitesse", 1.0))
			if vitesse == 1.0:
				animation.advance(delta)
			oneshot.t = float(oneshot.t) + delta * vitesse
			if vitesse != 1.0:
				animation.seek(maxf(0.0, float(oneshot.t)), true)
			if float(oneshot.t) >= float(oneshot.fin) if vitesse >= 0.0 else float(oneshot.t) <= float(oneshot.fin):
				var suite: Array = oneshot.suite
				entry.geste = {}
				if not suite.is_empty():
					var prochain: Array = suite[0] if suite[0] is Array else [suite[0]]
					jouer_geste(id, str(prochain[0]), float(prochain[1]) if prochain.size() > 1 else 0.0, float(prochain[2]) if prochain.size() > 2 else -1.0, bool(oneshot.ancre), suite.slice(1))
				else:
					entry.pace = -1
		elif animation:
			var pose_moving := moving or live_cut
			var clip: StringName
			var stride := 4.0
			if entry.adapted:
				# Quatre paliers (marche, trot, course, sprint) au lieu de deux.
				if moving or not live_cut:
					entry.pace = _animations_adaptees.palier(speed, entry.pace) if moving else -1
				var tier := maxi(int(entry.pace), 0)
				entry.running = tier >= 2 and moving
				clip = _animations_adaptees.clip(tier) if pose_moving else entry.idle
				stride = _animations_adaptees.allure(tier)
			else:
				# Hysteresis avoids changing support on every small speed fluctuation.
				if moving or not live_cut:
					entry.running = speed > (2.5 if entry.running else 3.3) if moving else false
				clip = (entry.run if entry.running else entry.walk) if pose_moving else entry.idle
				stride = 1.6 if clip == entry.walk else 4.0
			if not clip.is_empty() and animation.current_animation != clip:
				animation.play(clip, 0.18)
			# Frame-owned animation prevents an AnimationPlayer update from overwriting
			# the hand contact after the pose solver has run.
			animation.speed_scale = 1.0
			# Advance by travelled distance; no minimum cadence while the root creeps.
			var pose_delta := movement.length() / stride if pose_moving else delta
			animation.advance(0.0 if _paused else pose_delta)
		if entry.rig and not _paused:
			if staged or not entry.get("geste", {}).is_empty():
				entry.feet.clear()
			elif not live_cut:
				Presentation.support_feet(actor, entry.rig, entry.feet, speed, angle_difference(previous_heading, actor.rotation.y))
			else:
				entry.feet.clear()
			var cut_progress := progress
			if entry.cut_beat >= 0.0:
				entry.cut_beat = minf(CUT_SECONDS, float(entry.cut_beat) + delta)
				cut_progress = entry.cut_beat / CUT_SECONDS
				if cut_progress >= 1.0:
					entry.cut_beat = -1.0
					entry.cut_direction = 0
					entry.cut_plant.clear()
			if entry.cut_direction != 0 and cut_progress < 1.0:
				if live_cut:
					Cut.apply_live(actor, entry.rig, entry.cut_direction, cut_progress, entry.cut_pose, entry.cut_plant)
				else:
					Cut.apply(actor, entry.rig, entry.cut_direction, cut_progress, entry.cut_pose, entry.cut_plant)
	_impacts.avancer(delta)
	_update_contact(delta)
	# Poses des pistes avant le ballon : les mains du porteur sont à leur place quand il y est mis.
	if choregraphie_active():
		_choregraphie.pose()
	_update_ball(delta)
	mise_en_scene().pose()
	_poser_tenues(delta)
	if _formations:
		_formations.poser(delta)
	# Resolve upper-body contact after every source-animation update and after the
	# ball's continuous trajectory. A new receiver never pulls it across the pitch.
	for id: String in _actors:
		# Demi qui introduit en mêlée : il tient le ballon bas lui-même (match_formations.gd).
		if _is_pass_player(id) or mise_en_scene().stages(id) or (_formations != null and _formations.tient_ballon(id)):
			continue
		var entry: Dictionary = _actors[id]
		var actor: Node3D = entry.node
		var rig: Skeleton3D = entry.rig
		var center := Presentation.ball_anchor(actor, rig) if rig else Vector3.ZERO
		var approaching: bool = entry.holding and _ball.visible and center.distance_to(_ball.global_position) < 0.38
		var can_grip: bool = entry.holding and (_ball_attached or approaching)
		entry.grip = move_toward(float(entry.grip), 1.0 if can_grip else 0.0, delta * 6.0)
		if not entry.holding:
			entry.tenu = 0.0
			entry.cote_ballon = 0.0
			entry.porte = 0.0
		elif not _paused:
			entry.tenu = float(entry.get("tenu", 0.0)) + delta
		if rig and entry.grip > 0.0:
			if approaching and not _ball_attached:
				center = _ball.global_position
				Presentation.hold_ball(actor, rig, center, entry.grip)
			else:
				_porter_ballon(id, entry, delta)
		elif rig:
			_bras_hors_ballon(id, entry)
	_impacts.poser_ballon()
	if not _pass_plan.is_empty() and _pass_elapsed >= _pass_plan.duration:
		_stop_live_pass(true)
	# Repère au sol du ballon : seulement dans la vue de dessus, où le ballon est minuscule ;
	# jamais dans les vues de retransmission (pas de cercle aux pieds du porteur).
	_ball_marker.visible = _camera_mode == "tactical"
	# Vue de dessus seulement : disques et numéros des joueurs, balise jaune du ballon.
	Tactique.mettre_a_jour(_actors, _carrier_id, _camera_mode == "tactical")
	_ball_beacon.visible = _camera_mode == "tactical" and _ball.visible
	if _ball.visible:
		_ball_marker.global_position = Vector3(_ball.global_position.x, 0.028, _ball.global_position.z)
		# Ballon tenu par un joueur : anneau plus grand et plus brillant ; au sol : anneau discret.
		var tenu_en_main := not _carrier_id.is_empty() and _actors.has(_carrier_id)
		_ball_marker.global_basis = Basis.IDENTITY.scaled(Vector3.ONE * (1.45 if tenu_en_main else 1.0))
		((_ball_marker as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color("ffe680") if tenu_en_main else Color("e9bf5a")
	_fit_camera(delta, _camera_cut)
	_camera_cut = false


## Port du ballon par le porteur : deux mains (prise, passe proche, allure modérée) ou calé sous
## le bras tourné vers la caméra (course lancée). Le ballon suit les poignets.
const PORT_SOUS_LE_BRAS := 4.3     # allure (m/s) à partir de laquelle le ballon est calé sous le bras
const PORT_APRES_PRISE := 0.5      # deux mains au moins pendant ce temps après la prise
const PASSE_ARMEE := 0.42          # armé de la passe avant le lâcher, en secondes
const PASSE_FIN := 0.3             # fin du geste de passe après le lâcher

func _porter_ballon(id: String, entry: Dictionary, delta: float) -> void:
	var actor: Node3D = entry.node
	var swing := -1.0
	var toward := 1.0
	if choregraphie_active():
		var passe: Dictionary = _choregraphie.passe_de(id, 0.0, PASSE_ARMEE)
		if not passe.is_empty():
			swing = 1.0 - clampf((float(passe.t) - _choregraphie.temps) / PASSE_ARMEE, 0.0, 1.0)
			toward = _cote_de(actor, str(passe.vers))
	var voulu := 1.0 if swing < 0.0 and float(entry.get("allure", 0.0)) >= PORT_SOUS_LE_BRAS and float(entry.get("tenu", 0.0)) >= PORT_APRES_PRISE else 0.0
	entry.tuck = move_toward(float(entry.get("tuck", 0.0)), voulu, delta * 3.0)
	if float(entry.get("cote_ballon", 0.0)) == 0.0:
		# Calé sous le bras tourné vers la caméra, choisi à la prise : le ballon reste visible.
		var vers_camera := _camera.global_position - actor.global_position if is_instance_valid(_camera) else Vector3.BACK
		entry.cote_ballon = 1.0 if actor.global_basis.x.dot(Vector3(vers_camera.x, 0.0, vers_camera.z)) >= 0.0 else -1.0
	var tenue: Array = Presentation.carry_ball(actor, entry.rig, float(entry.grip), float(entry.tuck), float(entry.cote_ballon), swing, toward)
	var possede: bool = _ball_attached and _carrier_id == id and not mise_en_scene().owns_ball()
	# Raccord en 0,2 s depuis la place donnée par la trajectoire (prise, passe reçue).
	entry.porte = move_toward(float(entry.get("porte", 0.0)), 1.0 if possede else 0.0, delta * 5.0)
	if possede and not _paused:
		var w := smoothstep(0.0, 1.0, float(entry.porte))
		_ball.global_position = _ball.global_position.lerp(tenue[0], w)
		_ball.global_basis = _ball.global_basis.orthonormalized().slerp((tenue[1] as Basis).orthonormalized(), w)


## Bras sans ballon : fin du geste de passe, ou mains tendues vers le ballon qui arrive.
func _bras_hors_ballon(id: String, entry: Dictionary) -> void:
	if not choregraphie_active():
		return
	var actor: Node3D = entry.node
	var passe: Dictionary = _choregraphie.passe_de(id, PASSE_FIN, 0.0)
	if not passe.is_empty():
		var age: float = _choregraphie.temps - float(passe.t)
		Presentation.pass_follow(actor, entry.rig, _cote_de(actor, str(passe.vers)), 1.0 - clampf(age / PASSE_FIN, 0.0, 1.0))
		return
	var prise: float = _choregraphie.reception_de(id, 0.45)
	if prise > 0.0 and _ball.visible:
		Presentation.reach_ball(actor, entry.rig, _ball.global_position, 1.0 - clampf((prise - _choregraphie.temps) / 0.45, 0.0, 1.0))


## Côté (1 gauche, -1 droite, repère du joueur) où se trouve `autre`.
func _cote_de(actor: Node3D, autre: String) -> float:
	if not _actors.has(autre):
		return 1.0
	var local := actor.global_basis.inverse() * ((_actors[autre].node as Node3D).global_position - actor.global_position)
	return 1.0 if local.x >= 0.0 else -1.0


func _is_pass_player(id: String) -> bool:
	return not _pass_plan.is_empty() and (id == _pass_plan.passer or id == _pass_plan.receiver)


func _stage_live_pass() -> void:
	for id: String in [_pass_plan.passer, _pass_plan.receiver]:
		if not _actors.has(id) or not is_instance_valid(_actors[id].rig):
			_pass_plan.clear()
			return
	var release: Vector2 = _pass_plan.origin
	var catch_point: Vector2 = _pass_plan.catch_point
	_pass_plan.ball_from = _ball.global_position
	_pass_plan.ball_basis = _ball.global_basis
	_pass_plan.duration = Pass.LIVE_SECONDS if _live_cadence == 1 else Pass.FAST_LIVE_SECONDS
	_pass_plan.staging = {}
	_contact_plan.clear()
	for id: String in [_pass_plan.passer, _pass_plan.receiver]:
		var sending: bool = id == _pass_plan.passer
		var point := release if sending else catch_point
		var facing := catch_point - release if sending else release - catch_point
		var entry: Dictionary = _actors[id]
		_pass_plan.staging[id] = {"from": entry.node.position, "mark": Vector3(point.x - 50.0, 0.0, point.y - 35.0),
			"heading": entry.node.rotation.y, "facing": atan2(facing.x, facing.y)}
		entry.elapsed = 0.0
		entry.tangent = Vector3.ZERO
		entry.velocity = Vector3.ZERO
		entry.feet.clear()
		entry.grip = 0.0


func _stop_live_pass(completed: bool = false) -> void:
	if _pass_plan.is_empty():
		return
	for id: String in [_pass_plan.passer, _pass_plan.receiver]:
		if _actors.has(id):
			# Nouveau trajet depuis la marque de la passe : sa durée suit la distance qui reste
			# (celle fixée avant la passe, depuis l'ancienne place, ralentirait le porteur).
			var entry: Dictionary = _actors[id]
			entry.from = entry.node.position
			entry.duree = Motion.duree(entry.from, entry.target)
			entry.elapsed = 0.0
	if not completed:
		_ball_from = _ball.global_position
		_ball_from_basis = _ball.global_basis
		_ball_travel = 0.0
	_pass_plan.clear()
	_pass_elapsed = 0.0


func _update_live_pass() -> bool:
	var passer: Dictionary = _actors[_pass_plan.passer]
	var receiver: Dictionary = _actors[_pass_plan.receiver]
	var passer_anchor := Presentation.ball_anchor(passer.node, passer.rig)
	if _pass_elapsed < Pass.PREP_SECONDS:
		var preparation := smoothstep(0.0, Pass.PREP_SECONDS, _pass_elapsed)
		_ball.global_position = (_pass_plan.ball_from as Vector3).lerp(passer_anchor, preparation)
		_ball.global_basis = (_pass_plan.ball_basis as Basis).slerp(passer.node.global_basis, preparation)
		Pass.pose(passer.node, passer.rig, _ball.global_position, preparation, passer.contact_base)
		return true
	var progress := inverse_lerp(Pass.PREP_SECONDS, _pass_plan.duration, _pass_elapsed)
	var sample := Pass.sample(progress, passer_anchor,
		Presentation.ball_anchor(receiver.node, receiver.rig))
	if sample.is_empty():
		_stop_live_pass()
		return false
	_ball.global_position = sample.ball
	_ball.global_basis = receiver.node.global_basis if sample.stage == "received" else passer.node.global_basis
	Pass.pose(passer.node, passer.rig, sample.passer_target, sample.passer_weight, passer.contact_base)
	Pass.pose(receiver.node, receiver.rig, sample.receiver_target, sample.receiver_weight, receiver.contact_base)
	if _pass_elapsed >= _pass_plan.duration:
		_ball_attached = true
		_ball_travel = 1.0
		receiver.grip = 1.0
	return true


func _update_contact(delta: float) -> void:
	var carrier: String = _contact_plan.get("carrier", "")
	var opponent: String = _contact_plan.get("opponent", "")
	var active := _ball_attached and _actors.has(carrier) and _actors.has(opponent)
	var strength := 0.0
	if active:
		strength = Contact.strength(_actors[carrier].node.position, _actors[opponent].node.position)
	for id: String in _actors:
		var entry: Dictionary = _actors[id]
		# Clear immediately on an excluded action/pause/removal; fade only within
		# the same eligible geometry. A stale pair must never keep an actor posed.
		if not active or id not in [carrier, opponent]:
			entry.contact_weight = 0.0
			continue
		entry.contact_weight = minf(strength, move_toward(float(entry.contact_weight), strength, delta * 5.0))
	if not active: return
	# Apply the carrier first so the opponent reads the same current chest pose,
	# irrespective of insertion order in the transmitted presence list.
	for id: String in [carrier, opponent]:
		var entry: Dictionary = _actors[id]
		var other: Dictionary = _actors[opponent if id == carrier else carrier]
		if entry.rig and other.rig:
			Presentation.brace_contact(entry.node, entry.rig, other.node, other.rig, entry.contact_weight, id == carrier, entry.contact_base)


func _update_ball(delta: float) -> void:
	if choregraphie_active():
		_ball_des_pistes()
		return
	if not _ball.visible:
		return
	if mise_en_scene().owns_ball():
		return
	if not _pass_plan.is_empty() and _update_live_pass():
		return
	_ball_travel = minf(1.0, _ball_travel + delta / duree_vol())
	if _tir_au_but():
		# Tir au but : au-dessus de la barre, puis le ballon retombe dans l'en-but (match_apres_essai.gd).
		_ball_attached = false
		_ball.position = ApresEssai.vol(_ball_from, _ball_target, _ball_travel)
		return
	if not _carrier_id.is_empty() and _actors.has(_carrier_id) and _actors[_carrier_id].rig:
		var entry: Dictionary = _actors[_carrier_id]
		var anchor := Presentation.ball_anchor(entry.node, entry.rig)
		if _ball_travel >= 1.0:
			_ball_attached = true
		_ball.global_position = anchor if _ball_attached else _ball_from.lerp(anchor, _ball_travel)
		_ball.global_basis = entry.node.global_basis if _ball_attached else _ball_from_basis.slerp(entry.node.global_basis, _ball_travel)
	else:
		_ball_attached = false
		_ball.position = _ball_from.lerp(_ball_target, _ball_travel)
		# Seuls les coups de pied existants utilisent cet arc générique.
		if _kind in ["kick", "goal", "miss", "kickoff", "drop22", "goalLine"]:
			_ball.position.y += sin(_ball_travel * PI) * minf(6.0, _ball_from.distance_to(_ball_target) * 0.18)


## Ballon des pistes : dans les mains de son porteur, sinon sur sa trajectoire (passe,
## ballon au sol, aplati).
func _ball_des_pistes() -> void:
	_ball.visible = true
	var porteur: String = _choregraphie.porteur()
	_carrier_id = porteur
	for id: String in _actors:
		_actors[id].holding = id == porteur
	var tenu: bool = not porteur.is_empty() and _actors.has(porteur) and _actors[porteur].rig and _choregraphie.etat(porteur) != "aplati"
	var vise: Vector3 = _choregraphie.ballon_piste()
	if tenu:
		var entry: Dictionary = _actors[porteur]
		vise = Presentation.ball_anchor(entry.node, entry.rig)
		_ball.global_basis = (entry.node as Node3D).global_basis
	# Changement de source (prise, lâcher, ramassage, aplati) : le ballon rejoint la nouvelle
	# source en 0,2 s depuis sa place à l'écran, jamais d'un bond.
	var source := porteur + ("|tenu" if tenu else "|piste")
	if _choregraphie.coupe_ballon:
		# Coupe sur une remise en jeu formée : le ballon est déjà à sa place.
		_choregraphie.coupe_ballon = false
		_choregraphie.source_ballon = source
		_choregraphie.source_depuis = _choregraphie.temps - 1.0
		_choregraphie.source_de = vise
	if source != _choregraphie.source_ballon:
		_choregraphie.source_ballon = source
		_choregraphie.source_depuis = _choregraphie.temps
		_choregraphie.source_de = _ball.global_position
	var k := smoothstep(0.0, 0.2, _choregraphie.temps - _choregraphie.source_depuis)
	_ball.global_position = (_choregraphie.source_de as Vector3).lerp(vise, k)
	_ball_attached = tenu and k >= 1.0


func set_quality(profile: String) -> void:
	_quality = profile if profile in ["economy", "balanced", "detail"] else "balanced"
	if not is_node_ready():
		return
	# Godot's imported geometry LODs remain shared by the thirty actors.
	get_viewport().mesh_lod_threshold = {"economy": 4.0, "balanced": 2.0, "detail": 1.0}[_quality]
	if is_instance_valid(_sun):
		_sun.shadow_enabled = _quality != "economy"
	if _grass:
		_grass.set_shader_parameter("micro_detail", {"economy": 0.0, "balanced": 0.1, "detail": 0.16}[_quality])
	if _rendu:
		_rendu.appliquer()


func _fit_camera(delta: float = 0.0, cut: bool = false) -> void:
	if not is_instance_valid(_camera):
		return
	_camera_framed = true
	if _camera_mode != "tactical":
		var base := ACTION_TAILLE if _camera_mode == "action" else TV_TAILLE
		# Ballon absent : la caméra garde son point visé.
		var desired := _ball.global_position if _ball.visible else _camera_focus
		if cut:
			_camera_focus = desired
		else:
			_camera_focus = _camera_focus.lerp(desired, 1.0 - exp(-5.0 * delta))
			# Bound the follow delay during a long authored pass; the ball must
			# stay in the comfortable middle area even at the in-goal corners.
			var lag := _camera_focus - desired
			_camera_focus = desired + lag.limit_length(base * RETARD_MAX)
		var offset := offset_suivi(ACTION_OFFSET if _camera_mode == "action" else TV_OFFSET, _camera_focus.z)
		var look := _camera_focus
		var size := base
		var wide := size
		var screen := get_viewport().get_visible_rect().size
		if sortie and plan_sortie:
			# Sortie montrée de près : contrechamp qui suit le groupe vers le tunnel (prime sur le plan large).
			var vise := _vise_sortie()
			_sortie_vise = vise if cut or delta <= 0.0 else _sortie_vise.lerp(vise, 1.0 - exp(-delta / PLAN_SORTIE_LISSAGE))
			var sens := PLAN_SORTIE_OFFSET.normalized()
			_camera_look = _sortie_vise
			_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			_camera.global_transform = Transform3D(Basis.looking_at(-sens, Vector3.UP), _sortie_vise + sens * PLAN_SORTIE_RECUL)
			_camera.fov = PLAN_SORTIE_CHAMP
			return
		if _plan_large:
			# Mi-temps, fin de match : tout le terrain, sans recadrage.
			var direction := PLAN_LARGE_OFFSET.normalized()
			_camera_look = PLAN_LARGE_VISE
			_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			_camera.global_transform = Transform3D(Basis.looking_at(-direction, Vector3.UP), PLAN_LARGE_VISE + direction * PLAN_LARGE_RECUL)
			_camera.fov = PLAN_LARGE_CHAMP
			_camera.size = 2.0 * PLAN_LARGE_RECUL * tan(deg_to_rad(PLAN_LARGE_CHAMP * 0.5))
			return
		if _cadrage:
			# Pendant un temps fort : l'action est cadrée de près, le ballon toujours dans le champ.
			var close: Array = _cadrage.frame_camera(look, size, offset, screen.x / maxf(screen.y, 1.0), _camera_mode, delta, cut)
			look = close[0]
			size = close[1]
			offset = close[2]
			if _cadrage.has_method("dans_l_axe") and _cadrage.dans_l_axe():
				# Tir au but filmé dans l'axe (match_cadrage.gd) : posé tel quel, sans recadrage de geste
				# ni bornes de la caméra de tribune.
				if _gestes:
					_gestes.reset_framing()
				_poser_camera(look, size, offset)
				return
		if _gestes:
			# Pendant un geste : rapprochement amorti (et léger pivot lent en TV), puis retour.
			var framed: Array = _gestes.frame_camera(look, size, offset, screen.x / maxf(screen.y, 1.0), _camera_mode, delta)
			look = framed[0]
			size = framed[1]
			offset = framed[2]
			if float(_gestes.zoom) > 0.0:
				# Essai dans un coin : pivot limité et point visé gardé dans l'aire de jeu (pas de tribune).
				var suivi := offset_suivi(ACTION_OFFSET if _camera_mode == "action" else TV_OFFSET, _camera_focus.z)
				offset = borner_pivot(look, offset, suivi)
				look = look.lerp(borner_visee(look), smoothstep(0.0, 1.0, float(_gestes.zoom)))
			if _cadrage:
				# Temps fort : le cadrage du geste garde lui aussi le ballon dans le champ.
				look = _cadrage.garder_ballon(look, size, offset, screen.x / maxf(screen.y, 1.0))
		if _camera_mode == "action":
			# Caméra au contact : point visé toujours ramené dans l'aire de jeu (essai en coin : le
			# terrain, pas la tribune) ; le ballon reste gardé à l'image plus bas.
			look = borner_visee(look, VISEE_CONTACT)
		# Jamais de champ dégénéré, quel que soit le recadrage.
		if not is_finite(size) or size < 2.0 or not look.is_finite() or not offset.is_finite():
			look = _camera_focus
			size = wide
			offset = offset_suivi(ACTION_OFFSET if _camera_mode == "action" else TV_OFFSET, _camera_focus.z)
		# Caméra au contact : pivot amorti autour du point visé quand un poteau masquerait l'action
		# (cherché sur le point visé final de l'image précédente, déjà stable d'une image à l'autre).
		var contournement := 0.0
		if _camera_mode == "action":
			contournement = contournement_poteaux(look if cut or delta <= 0.0 else _camera_look, size, offset)
		if cut or delta <= 0.0:
			_contournement = contournement
			_contournement_vitesse = 0.0
		else:
			var pas_contournement: Array = Gestes._damp1(_contournement, contournement, _contournement_vitesse, delta)
			_contournement = pas_contournement[0]
			_contournement_vitesse = pas_contournement[1]
		if absf(_contournement) > 0.0001:
			offset = offset.rotated(Vector3.UP, _contournement)
		# Recentrage borné, amorti (pas d'à-coup quand une borne entre en jeu) ; le ballon ne sort
		# jamais de l'image, même pendant l'amortissement.
		var aspect := screen.x / maxf(screen.y, 1.0)
		var borne := _borner(look, size, offset, aspect) - look
		if cut or delta <= 0.0:
			_borne = borne
			_borne_vitesse = Vector3.ZERO
		else:
			var pas: Array = Gestes._damp3(_borne, borne, _borne_vitesse, delta, BORNE_LISSAGE)
			_borne = pas[0]
			_borne_vitesse = pas[1]
		look += _borne
		if _ball.visible:
			var vue := Basis.looking_at(-offset, Vector3.UP)
			var profondeur := Vector3(vue.z.x, 0.0, vue.z.z).normalized()
			# Ni hors de l'image, ni sous le bandeau du score ou la légende du direct.
			var haut := BALLON_LIMITE + (float(_cadrage.couvert_haut) if _cadrage else 0.0)
			var bas := 1.0 - BALLON_LIMITE - (float(_cadrage.couvert_bas) if _cadrage else 0.0)
			look += profondeur * _garder_ballon(0.0, look, size, offset, aspect, profondeur, _ball.global_position, 1, haut, bas)
			var largeur := Vector3(vue.x.x, 0.0, vue.x.z).normalized()
			look += largeur * _garder_ballon(0.0, look, size, offset, aspect, largeur, _ball.global_position, 0, BALLON_LIMITE, 1.0 - BALLON_LIMITE)
		_poser_camera(look, size, offset)
		return
	if _gestes:
		_gestes.reset_framing()
	_camera_focus = Vector3.ZERO
	_camera_look = Vector3.ZERO
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.position = Vector3(0, 150, 5)
	_camera.look_at(Vector3.ZERO)
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0:
		return
	var aspect := viewport_size.x / viewport_size.y
	var half_height := 0.0
	# Tactical retains the entire pitch and its five-metre presentation apron.
	for x in [-56.0, 56.0]:
		for z in [-41.0, 41.0]:
			var point := _camera.to_local(Vector3(x, 0, z))
			half_height = maxf(half_height, maxf(absf(point.y), absf(point.x) / aspect))
	_camera.size = maxf(half_height * 2.16, 88.0)


## Direction de la caméra suivie pour un point visé à `profondeur` (z) : celle de base, relevée
## progressivement près de la touche proche (caméra-grue, voir GRUE_*). Continue : pas d'à-coup.
## Caméra de biais (contact) : son lacet est rendu progressivement symétrique quand le point suivi
## (`largeur`, x ; par défaut celui de la caméra) approche du bout du terrain vers lequel elle
## regarderait (|x| de PIVOT_DEBUT à PIVOT_FIN) : elle se place alors derrière l'en-but et regarde
## vers l'intérieur du terrain, jamais vers la tribune du bout du terrain.
func offset_suivi(base: Vector3, profondeur: float, largeur: float = NAN) -> Vector3:
	if absf(base.x) > 0.0001:
		var x := _camera_focus.x if is_nan(largeur) else largeur
		# La caméra regarde vers -offset : le bout du terrain regardé est du côté de -base.x.
		var symetrie := smoothstep(PIVOT_DEBUT, PIVOT_FIN, -x * signf(base.x))
		if symetrie > 0.0:
			base = base.rotated(Vector3.UP, -2.0 * symetrie * atan2(base.x, base.z))
	var k := smoothstep(GRUE_DEBUT, GRUE_FIN, profondeur)
	if k <= 0.0:
		return base
	var horizontal := Vector3(base.x, 0.0, base.z)
	var depart := atan2(base.y, horizontal.length())
	# Plafond d'inclinaison (jamais sous l'angle de base) : pas de vue de dessus près de la touche.
	var elevation := minf(depart + deg_to_rad(GRUE_ANGLE) * k, maxf(depart, deg_to_rad(INCLINAISON_MAX)))
	return (horizontal.normalized() * cos(elevation) + Vector3.UP * sin(elevation)) * base.length()


## Pivot des gestes (caméra TV) : jamais plus de PIVOT_MAX rad autour de la direction de suivi, et
## rendu progressivement nul près d'une ligne de ballon mort (|x| de PIVOT_DEBUT à PIVOT_FIN) quand il
## tourne la vue vers le bout du terrain : un essai dans un coin ne montre pas la tribune.
const PIVOT_MAX := 0.2
const PIVOT_DEBUT := 25.0
const PIVOT_FIN := 42.0
## Point visé pendant un geste : dans l'aire de jeu, à |x| <= VISEE_GESTE.x et |z| <= VISEE_GESTE.y.
const VISEE_GESTE := Vector2(47.0, 28.0)


func borner_pivot(look: Vector3, offset: Vector3, suivi: Vector3) -> Vector3:
	var avant := Vector2(suivi.x, suivi.z)
	var apres := Vector2(offset.x, offset.z)
	if avant.length() < 0.001 or apres.length() < 0.001:
		return offset
	# Angle de lacet autour de l'axe vertical (même sens que Vector3.rotated(Vector3.UP, angle)).
	var angle := wrapf(atan2(apres.x, apres.y) - atan2(avant.x, avant.y), -PI, PI)
	var permis := clampf(angle, -PIVOT_MAX, PIVOT_MAX)
	# La caméra regarde vers -offset : vers le bout du terrain le plus proche du point visé ?
	if -offset.x * look.x > 0.0:
		permis *= 1.0 - smoothstep(PIVOT_DEBUT, PIVOT_FIN, absf(look.x))
	if absf(permis - angle) < 0.00001:
		return offset
	return suivi.normalized().rotated(Vector3.UP, permis) * offset.length()


## Caméra au contact, en permanence : point visé à |x| <= VISEE_CONTACT.x et |z| <= VISEE_CONTACT.y.
const VISEE_CONTACT := Vector2(47.0, 30.0)


func borner_visee(look: Vector3, limites: Vector2 = VISEE_GESTE) -> Vector3:
	return Vector3(borne_douce(look.x, limites.x), look.y, borne_douce(look.z, limites.y))


## Borne sans à-coup : identité jusqu'à `limite - VISEE_GENOU`, puis approche progressive de la limite
## (vitesse continue) ; un ballon qui file vers le coin ne fait pas s'arrêter net le point visé.
const VISEE_GENOU := 5.0
static func borne_douce(valeur: float, limite: float) -> float:
	var debut := limite - VISEE_GENOU
	if absf(valeur) <= debut:
		return valeur
	return signf(valeur) * (debut + VISEE_GENOU * tanh((absf(valeur) - debut) / VISEE_GENOU))


## Un montant ou la barre des poteaux (élargis de POTEAU_MARGE) coupe le segment `depart` -> `arrivee`.
func poteau_entre(depart: Vector3, arrivee: Vector3, m: float = POTEAU_MARGE) -> bool:
	for x in [-POTEAUX_X, POTEAUX_X]:
		var boites: Array[AABB] = [
			AABB(Vector3(x - m, 0.0, -POTEAUX_Z - m), Vector3(2.0 * m, POTEAU_HAUT + m, 2.0 * m)),
			AABB(Vector3(x - m, 0.0, POTEAUX_Z - m), Vector3(2.0 * m, POTEAU_HAUT + m, 2.0 * m)),
			AABB(Vector3(x - m, BARRE_Y - m, -POTEAUX_Z - m), Vector3(2.0 * m, 2.0 * m, 2.0 * POTEAUX_Z + 2.0 * m)),
		]
		for boite: AABB in boites:
			if boite.intersects_segment(depart, arrivee) != null:
				return true
	return false


## Cibles que la caméra au contact doit voir : le point visé (à hauteur d'homme) et le ballon.
func _cibles_camera(look: Vector3) -> Array[Vector3]:
	var cibles: Array[Vector3] = [Vector3(look.x, 1.0, look.z)]
	if is_instance_valid(_ball) and _ball.visible:
		cibles.append(_ball.global_position)
	return cibles


## Un poteau masque une des cibles pour la caméra posée sur `look` dans la direction `offset`.
func poteau_masque(look: Vector3, size: float, offset: Vector3, marge: float = POTEAU_MARGE) -> bool:
	var camera: Vector3 = pose_camera(look, size, offset)[0]
	for cible: Vector3 in _cibles_camera(look):
		if poteau_entre(camera, cible, marge):
			return true
	return false


## Plus petit pivot (rad) qui dégage la vue des poteaux ; le sens déjà pris est essayé d'abord. Une
## caméra déjà tournée ne revient que si la vue d'origine est dégagée avec POTEAU_RELACHE m de marge
## (hystérésis : pas d'aller-retour quand le point visé glisse un peu en tournant).
const POTEAU_RELACHE := 1.5
func contournement_poteaux(look: Vector3, size: float, offset: Vector3) -> float:
	# Loin des poteaux : rien à chercher (coût nul la plupart du temps).
	if absf(absf(look.x) - POTEAUX_X) > 40.0:
		return 0.0
	var marge := POTEAU_RELACHE if absf(_contournement) > 0.01 else POTEAU_MARGE
	if not poteau_masque(look, size, offset, marge):
		return 0.0
	var sens := -1.0 if _contournement < 0.0 else 1.0
	var pas := int(round(CONTOURNEMENT_MAX / CONTOURNEMENT_PAS))
	for k in range(1, pas + 1):
		for signe: float in [sens, -sens]:
			var angle := signe * k * CONTOURNEMENT_PAS
			if not poteau_masque(look, size, offset.rotated(Vector3.UP, angle), marge):
				return angle
	return sens * CONTOURNEMENT_MAX


## Caméra suivie en perspective : `size` est la hauteur visible (m) au point visé `look`, `offset`
## la direction depuis ce point. `_camera.size` garde cette hauteur visible (régie, tests).
func _poser_camera(look: Vector3, size: float, offset: Vector3) -> void:
	var pose := pose_camera(look, size, offset)
	_camera_look = look
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.global_transform = Transform3D(Basis.looking_at(-offset, Vector3.UP), pose[0])
	_camera.fov = pose[1]
	_camera.size = size


## Position de la caméra et angle de champ vertical (degrés) pour voir `size` m de haut au point
## visé. Au-delà de RECUL_MAX (tribune proche), la caméra avance et ouvre son angle.
func pose_camera(look: Vector3, size: float, offset: Vector3) -> Array:
	var direction := offset.normalized()
	var demi := size * 0.5
	var champ := ACTION_CHAMP if _camera_mode == "action" else TV_CHAMP
	var distance := demi / tan(deg_to_rad(champ * 0.5))
	if direction.z > 0.05 and _sous_le_toit(look, direction, distance, demi):
		# Le bas de l'image passerait sous le toit de la tribune proche : la caméra avance (et
		# ouvre son angle) juste assez pour le franchir, sans que le bas de l'image dépasse PLONGEE_MAX.
		var inclinaison := rad_to_deg(asin(clampf(direction.y, -1.0, 1.0)))
		var ouverture := clampf(2.0 * (PLONGEE_MAX - inclinaison), champ, CHAMP_MAX)
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
func _sous_le_toit(look: Vector3, direction: Vector3, distance: float, demi: float) -> bool:
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
func ecran_camera(point: Vector3, look: Vector3, size: float, offset: Vector3, aspect: float) -> Vector2:
	var pose := pose_camera(look, size, offset)
	var local: Vector3 = Basis.looking_at(-offset, Vector3.UP).inverse() * (point - (pose[0] as Vector3))
	var profondeur := -local.z
	if profondeur < 0.05:
		return Vector2(0.5, 10.0)
	var pente := tan(deg_to_rad(float(pose[1]) * 0.5))
	return Vector2(0.5 + 0.5 * local.x / (profondeur * pente * maxf(aspect, 0.1)), 0.5 - 0.5 * local.y / (profondeur * pente))


## Recentrage borné : le point visé glisse (en profondeur, puis en largeur) juste assez pour que la
## tribune et les abords n'occupent qu'une bande au bord de l'image, sans que le ballon quitte la
## zone sûre. Si l'image est plus grande que le terrain, le terrain y est centré.
func _borner(look: Vector3, size: float, offset: Vector3, aspect: float) -> Vector3:
	var ballon := _ball.global_position if _ball.visible else look
	var haut_sur := BALLON_SUR
	var bas_sur := 1.0 - BALLON_SUR
	var bord_haut := BORD_HAUT
	var bord_bas := BORD_BAS
	if _cadrage:
		# L'interface du direct couvre le haut et le bas : le ballon reste dans la partie visible,
		# et ce qui est sous le bandeau ou la légende ne compte pas comme tribune à l'image.
		haut_sur = maxf(haut_sur, float(_cadrage.couvert_haut) + 0.08)
		bas_sur = minf(bas_sur, 1.0 - float(_cadrage.couvert_bas) - 0.08)
		bord_haut = maxf(bord_haut, float(_cadrage.couvert_haut) + 0.02)
		bord_bas = minf(bord_bas, 1.0 - float(_cadrage.couvert_bas) - 0.02)
	var loin := -TERRAIN.y - TERRAIN_MARGE
	var pres := TERRAIN.y + TERRAIN_MARGE
	var bout := TERRAIN.x + TERRAIN_MARGE
	# Axes de la caméra au sol : un glissement en largeur ne change pas la hauteur à l'écran.
	var vue := Basis.looking_at(-offset, Vector3.UP)
	var largeur := Vector3(vue.x.x, 0.0, vue.x.z).normalized()
	# Profondeur : touche lointaine en haut, touche proche en bas.
	var axe := Vector3(vue.z.x, 0.0, vue.z.z).normalized()
	var bornes := Vector2(
		_seuil(look, size, offset, aspect, axe, Vector3(look.x, 0.0, loin), 1, bord_haut, true).x,
		_seuil(look, size, offset, aspect, axe, Vector3(look.x, 0.0, pres), 1, bord_bas, false).y)
	var s := clampf(0.0, bornes.x, bornes.y) if bornes.x <= bornes.y else (bornes.x + bornes.y) * 0.5
	s = _garder_ballon(s, look, size, offset, aspect, axe, ballon, 1, haut_sur, bas_sur)
	look += axe * s
	# Largeur : lignes de ballon mort sur les bords.
	axe = largeur
	bornes = Vector2(
		_seuil(look, size, offset, aspect, axe, Vector3(-bout, 0.0, look.z), 0, BORD_COTE, true).x,
		_seuil(look, size, offset, aspect, axe, Vector3(bout, 0.0, look.z), 0, 1.0 - BORD_COTE, false).y)
	s = clampf(0.0, bornes.x, bornes.y) if bornes.x <= bornes.y else (bornes.x + bornes.y) * 0.5
	s = _garder_ballon(s, look, size, offset, aspect, axe, ballon, 0, BALLON_SUR, 1.0 - BALLON_SUR)
	return look + axe * s


## Décalage limité (ou imposé) pour que le ballon reste entre `bas` et `haut` sur la coordonnée
## d'écran `c`, en vraie perspective (ballon haut et proche de la caméra compris).
func _garder_ballon(s: float, look: Vector3, size: float, offset: Vector3, aspect: float, axe: Vector3, ballon: Vector3, c: int, bas: float, haut: float) -> float:
	var a := _seuil(look, size, offset, aspect, axe, ballon, c, haut, true)
	var b := _seuil(look, size, offset, aspect, axe, ballon, c, bas, false)
	var permis := Vector2(maxf(a.x, b.x), minf(a.y, b.y))
	return clampf(s, permis.x, permis.y) if permis.x <= permis.y else s


const DECALAGE_MAX := 30.0
## Intervalle [min, max] des décalages s du point visé le long de `axe` pour lesquels la coordonnée
## d'écran `c` (0 : x, 1 : y) de `point` reste sous `cible` (`sous`) ou au-dessus.
func _seuil(look: Vector3, size: float, offset: Vector3, aspect: float, axe: Vector3, point: Vector3, c: int, cible: float, sous: bool) -> Vector2:
	var a := -DECALAGE_MAX
	var b := DECALAGE_MAX
	var fa: float = ecran_camera(point, look + axe * a, size, offset, aspect)[c]
	var fb: float = ecran_camera(point, look + axe * b, size, offset, aspect)[c]
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
		var fm: float = ecran_camera(point, look + axe * m, size, offset, aspect)[c]
		if (fm <= cible) == (fa <= cible):
			a = m
			fa = fm
		else:
			b = m
	var limite := (a + b) * 0.5
	return Vector2(-INF, limite) if valable_bas else Vector2(limite, INF)


## Regroupement en cours (mêlée, touche, ruck) : places du paquet et des demis, pour un cadrage serré
## sur lui plutôt que sur les arrières écartés. Vide hors regroupement.
func regroupement() -> Array[Vector3]:
	var ids: Array = []
	var formation: Dictionary = _formations.formation if _formations and _formations.active() else {}
	var roles: Dictionary = formation.get("roles", {})
	var retenus: Array = []
	match str(formation.get("type", "")):
		"melee", "sortie_melee":
			retenus = ["pack", "demi_intro", "demi_adverse"]
		"touche":
			retenus = ["lanceur", "alignement", "sauteur", "demi"]
	for id: String in roles:
		if roles[id] in retenus:
			ids.append(id)
	if ids.is_empty() and not _impacts.ruck.is_empty():
		ids = _impacts.ruck.keys()
		for autre: String in [_impacts.porteur, _impacts.plaqueur]:
			if not autre.is_empty() and autre not in ids:
				ids.append(autre)
	var centre := _ball.global_position if _ball.visible else _camera_focus
	var places: Array[Vector3] = []
	for id: String in ids:
		if _actors.has(id):
			var place: Vector3 = (_actors[id].node as Node3D).position
			# Un demi resté loin (touche) ne fait pas partie du regroupement.
			if Vector2(place.x - centre.x, place.z - centre.z).length() <= 18.0:
				places.append(Vector3(place.x, 0.0, place.z))
	return places


func _world(point: Dictionary, height: float = 0.0) -> Vector3:
	return Vector3(float(point.get("x", 50)) - 50.0, height, float(point.get("y", 35)) - 35.0)


func _clear_presence() -> void:
	for entry: Dictionary in _actors.values():
		_players.remove_child(entry.node)
		entry.node.queue_free()
	_actors.clear()
	_ball.visible = false
	_carrier_id = ""
	_action_key = ""
	mise_en_scene().cancel()
	_pass_plan.clear()
	_pass_elapsed = 0.0
	_contact_plan = {}
	_impacts.annuler()
	_ball_attached = false
	# Scène vide : plus rien à suivre, la caméra revient au centre du terrain.
	_camera_focus = Vector3.ZERO
	_camera_cut = true
	_fit_camera(0.0, true)


func _make_actor(id: String, side: int, target: Vector3) -> Dictionary:
	var actor := Node3D.new()
	actor.name = "Athlete_" + id.validate_node_name()
	_players.add_child(actor)
	actor.position = target
	actor.rotation.y = PI * 0.5 if side == 0 else -PI * 0.5
	# Aucun repère au sol (anneau aux couleurs de l'équipe) : retiré à la demande de Léo
	# (12 novembre 2026), « ça fait pas réaliste ». Les maillots suffisent à distinguer les équipes.
	var model := _athlete_scene.instantiate() as Node3D
	actor.add_child(model)
	model.set_meta("athlete_id", id)
	# Imported source contains a 100x mesh transform; calibrate its real rest bounds.
	var bounds := _model_bounds(model, model)
	if bounds.size.y > 0.001:
		var calibration := 1.9 / bounds.size.y
		model.scale = Vector3.ONE * calibration
		model.position.y = -bounds.position.y * calibration
	Athlete.prepare(model)
	_recolor(model, side)
	if _rendu:
		_rendu.equiper_joueur(actor)
	var squelette := Presentation.rig_for(model)
	if squelette:
		squelette.set_meta("repos_relatif", actor.global_basis.inverse() * squelette.global_basis)
	var animation := _find_animation(model)
	var idle := StringName()
	var run := StringName()
	var walk := StringName()
	var adapted := false
	if animation:
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: StringName in animation.get_animation_list():
			if str(clip).ends_with("Man_Idle"):
				idle = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			if str(clip).ends_with("Man_Run"):
				run = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			if str(clip).ends_with("Man_Walk"):
				walk = clip
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if _animations_adaptees and _animations_adaptees.equiper(animation):
			adapted = true
			idle = _animations_adaptees.repos()
		if not idle.is_empty():
			animation.play(idle)
	return {"node": actor, "model": model, "side": side, "from": target, "target": target,
		"elapsed": BLEND_SECONDS, "duree": BLEND_SECONDS, "velocity": Vector3.ZERO, "tangent": Vector3.ZERO, "running": false,
		"feet": {}, "cut_direction": 0, "cut_idle": BLEND_SECONDS, "cut_beat": -1.0, "cut_normal_speed": false, "cut_pose": {}, "cut_plant": {},
		"contact_base": {}, "contact_weight": 0.0,
		"animation": animation, "idle": idle, "run": run, "walk": walk, "adapted": adapted, "pace": -1, "geste": {}, "rig": Presentation.rig_for(model), "holding": false, "grip": 0.0,
		"allure": 0.0, "tenu": 0.0, "tuck": 0.0, "cote_ballon": 0.0, "porte": 0.0}


func _model_bounds(node: Node3D, origin: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var relative := origin.global_transform.affine_inverse() * mesh.global_transform
		var part: AABB = relative * mesh.get_aabb()
		result = result.merge(part) if found else part
		found = true
	return result


func _find_animation(node: Node) -> AnimationPlayer:
	for child: Node in node.get_children():
		if child is AnimationPlayer:
			return child
		var nested := _find_animation(child)
		if nested:
			return nested
	return null


func _refresh_kits() -> void:
	_kits = Kit.resolve(_team_colors)


func alternative_kit_colors() -> Array[Color]:
	if _kits.size() != 2 or _kits[1].shirt == _team_colors[1]:
		return []
	return [_kits[0].shirt, _kits[1].shirt]


func _recolor(model: Node3D, side: int) -> void:
	Athlete.dress(model, _kits[side], str(model.get_meta("athlete_id", "")))

func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6b7d89")
	sky_material.sky_horizon_color = Color("d7dcd8")
	sky_material.ground_bottom_color = Color("29383a")
	sky_material.ground_horizon_color = Color("c5cfca")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c6cfd1")
	settings.ambient_light_energy = 0.43
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	_sun = sun
	# Neutral art lighting, not an assertion about the match's time or weather.
	sun.rotation_degrees = Vector3(-57, -24, 0)
	sun.light_color = Color("fff6e9")
	sun.light_energy = 0.92
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 230
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.14
	add_child(sun)


func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _box(size: Vector3, position_: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = position_
	if size.y < 0.1:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _build_ground() -> void:
	var first_child := get_child_count()
	var dark := _material(Color("202b2c"))
	_box(Vector3(220, 0.4, 180), Vector3(0, -0.45, 0), dark).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(135, 0.2, 96), Vector3(0, -0.2, 0), _material(Color("464c49"))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(118, 0.1, 80), Vector3(0, -0.09, 0), _material(Color("284c31"))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# One original shader, no external texture or time-dependent grass noise.
	var grass := ShaderMaterial.new()
	_grass = grass
	grass.shader = load("res://shaders/stadium_surface.gdshader") as Shader
	_box(Vector3(110, 0.12, 70), Vector3(0, -0.07, 0), grass).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := _material(Color("efefdf"))
	for z in [-35.0, 35.0]:
		_box(Vector3(110, 0.018, 0.16), Vector3(0, 0.008, z), paint)
	for x in [-55.0, -50.0, -28.0, 0.0, 28.0, 50.0, 55.0]:
		_box(Vector3(0.16, 0.018, 70), Vector3(x, 0.008, 0), paint)
	for x in [-45.0, -10.0, 10.0, 45.0]:
		for z in range(-32, 33, 8):
			_box(Vector3(0.13, 0.018, 3), Vector3(x, 0.009, z), paint)
	for z in [-30.0, -20.0, 20.0, 30.0]:
		for x in range(-45, 46, 10):
			_box(Vector3(3, 0.018, 0.13), Vector3(x, 0.009, z), paint)
	for x in [-50.0, 50.0]:
		for z in [-2.8, 2.8]:
			_box(Vector3(0.17, 12, 0.17), Vector3(x, 6, z), paint)
			_box(Vector3(0.42, 1.6, 0.42), Vector3(x, 0.8, z), _material(Color("263b49")))
		_box(Vector3(0.17, 0.17, 5.6), Vector3(x, 3, 0), paint)
	for x in [-50.0, 50.0]:
		for z in [-35.0, 35.0]:
			_box(Vector3(0.07, 1.4, 0.07), Vector3(x, 0.7, z), paint)
			_box(Vector3(0.48, 0.3, 0.025), Vector3(x + 0.2, 1.3, z), _material(Color("e1ba66")))
	# Le rendu moderne projette les ombres de contact sur ces seuls éléments.
	for index in range(first_child, get_child_count()):
		if get_child(index) is MeshInstance3D:
			_ground_meshes.append(get_child(index))


func _build_stadium() -> void:
	# Generic architecture, deliberately unrelated to a named real-world stadium.
	var concrete := _material(Color("545c5d"))
	var anthracite := _material(Color("202c33"))
	var ivory := _material(Color("a9b1a9"))
	var roof := _material(Color("4d6067"))
	var steel := _material(Color("7f9195"))
	var seat := _material(Color("374e57"))
	var aisle := _material(Color("a99e7c"))
	var lamp := _material(Color("e8dec2"), true)
	var spectator_positions: Array[Vector3] = []
	var spectator_rotations: Array[float] = []
	var seat_transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 271828 # Local visual randomness must never consume engine RNG.
	for side in [-1.0, 1.0]:
		# Eight separated bays, readable aisles and recessed entrances.
		for bay in 8:
			var center := -56.0 + bay * 16.0
			for row in 10:
				var height := 0.65 + row * 0.74
				var z: float = side * (46.0 + row * 1.24)
				_venue_box(Vector3(14.1, height, 1.24), Vector3(center, height * 0.5, z), concrete)
				_venue_box(Vector3(14.1, 0.08, 0.17), Vector3(center, height + 0.05, z - side * 0.55), ivory)
				for place in 20:
					var x := center - 6.65 + place * 0.7
					var sitting := Vector3(x, height + 0.43, z)
					seat_transforms.append(Transform3D(Basis().rotated(Vector3.UP, PI if side > 0 else 0), sitting))
					if rng.randf() > 0.22:
						spectator_positions.append(sitting + Vector3(rng.randf_range(-0.06, 0.06), 0.05, 0.08 * side))
						spectator_rotations.append(PI if side > 0 else 0.0)
			# Recesses remain behind seating, no spurious actors in the technical area.
			_venue_box(Vector3(2.1, 2.6, 1.4), Vector3(center + 8, 1.2, side * 45.6), anthracite)
			for stair in 20:
				var height := 0.32 + stair * 0.37
				_venue_box(Vector3(1.6, height, 0.62), Vector3(center + 8, height * 0.5, side * (45.7 + stair * 0.62)), concrete)
				_venue_box(Vector3(1.6, 0.025, 0.1), Vector3(center + 8, height + 0.02, side * (45.42 + stair * 0.62)), aisle)
			_venue_beam(Vector3(center + 8, 2.4, side * 47), Vector3(center + 8, 8.2, side * 56.8), 0.07, steel)
		# Continuous rear concourse and a restrained floating canopy.
		_venue_box(Vector3(132, 8.8, 1.0), Vector3(0, 4.2, side * 60.4), anthracite)
		_venue_box(Vector3(132, 0.28, 5.5), Vector3(0, 8.7, side * 59), concrete)
		_venue_box(Vector3(133, 0.38, 8.5), Vector3(0, 12.4, side * 59.1), roof)
		_venue_box(Vector3(133, 0.65, 0.22), Vector3(0, 12.3, side * 54.8), anthracite)
		_venue_box(Vector3(132, 0.09, 0.11), Vector3(0, 11.99, side * 54.67), lamp)
		for x in range(-64, 65, 16):
			_venue_box(Vector3(0.22, 12.4, 0.22), Vector3(x, 6.1, side * 61), steel)
			_venue_beam(Vector3(x, 9.5, side * 61), Vector3(x, 12.1, side * 54.8), 0.15, steel)
			_venue_box(Vector3(0.1, 0.18, 8.4), Vector3(x, 12.7, side * 59.1), steel)
		# Original perimeter boards, not real sponsors or fictional attendance.
		for board in 8:
			var x := -56.0 + board * 16.0
			_venue_box(Vector3(15.5, 1.05, 0.22), Vector3(x, 0.58, side * 41.2), anthracite)
			_venue_box(Vector3(15.5, 0.06, 0.24), Vector3(x, 1.13, side * 41.2), ivory)
			_stadium_advert(Vector3(x, 0.65, side * 41.04), PI if side > 0 else 0.0)
		# Modest end terraces leave both in-goals unobstructed.
		for row in 7:
			var height := 0.65 + row * 0.72
			var x: float = side * (65.2 + row * 1.25)
			_venue_box(Vector3(1.25, height, 85), Vector3(x, height * 0.5, 0), concrete)
			_venue_box(Vector3(0.15, 0.07, 85), Vector3(x - side * 0.54, height + 0.04, 0), ivory)
			for place in 112:
				var z := -41.6 + place * 0.75
				if place % 28 < 3:
					continue
				var sitting := Vector3(x, height + 0.43, z)
				seat_transforms.append(Transform3D(Basis().rotated(Vector3.UP, -side * PI * 0.5), sitting))
				if rng.randf() > 0.3:
					spectator_positions.append(sitting)
					spectator_rotations.append(-side * PI * 0.5)
		_venue_box(Vector3(0.4, 1.1, 87), Vector3(side * 74, 5.3, 0), anthracite)
		_venue_box(Vector3(0.14, 0.12, 87), Vector3(side * 73.8, 5.9, 0), steel)
		for z in [-22.0, 22.0]:
			_venue_box(Vector3(0.22, 1.05, 21), Vector3(side * 60.1, 0.58, z), anthracite)
		# Empty technical shelters are architecture, not invented staff/substitutes.
		_venue_box(Vector3(11.5, 0.14, 2.2), Vector3(side * 18, 2.2, 43.1), ivory)
		_venue_box(Vector3(11.5, 2.2, 0.18), Vector3(side * 18, 1.1, 44.1), anthracite)
		for x in [-5.6, 5.6]:
			_venue_box(Vector3(0.12, 2.2, 2.2), Vector3(side * 18 + x, 1.1, 43.1), steel)
	# Four compact light heads. No expensive spotlights, GI or volumetric effects.
	for x in [-62.0, 62.0]:
		for z in [-43.5, 43.5]:
			_venue_box(Vector3(0.24, 18, 0.24), Vector3(x, 9, z), steel)
			_venue_box(Vector3(3.7, 1.1, 0.38), Vector3(x, 18, z), anthracite)
			for bulb in 5:
				_venue_box(Vector3(0.49, 0.58, 0.06), Vector3(x - 1.4 + bulb * 0.7, 18.03, z - signf(z) * 0.22), lamp)
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.52, 0.55, 0.43)
	_instance_batch("VenueSeats", seat_mesh, seat, seat_transforms)
	_build_spectators(spectator_positions, spectator_rotations, rng)
	_venue_box(Vector3(43, 3.8, 0.24), Vector3(0, 10.6, -54.8), anthracite)
	_build_club_branding()


func _build_club_branding() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = quad
	batch.instance_count = 1 # The stadium fascia carries the managed club crest.
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.1
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_club_branding = MultiMeshInstance3D.new()
	_club_branding.name = "ManagedClubCrests"
	_club_branding.multimesh = batch
	_club_branding.material_override = material
	_club_branding.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_club_branding)
	_update_club_branding()


func _update_club_branding() -> void:
	_club_branding.visible = _club_crest != null
	var material := _club_branding.material_override as StandardMaterial3D
	material.albedo_texture = _club_crest
	if _club_crest == null:
		return
	var aspect := float(_club_crest.get_width()) / maxf(1.0, _club_crest.get_height())
	var height := minf(2.9, 12.0 / maxf(aspect, 0.01))
	_club_branding.multimesh.set_instance_transform(0,
		Transform3D(Basis.from_scale(Vector3(height * aspect, height, 1.0)), Vector3(0, 10.6, -54.6)))


func _stadium_advert(position_: Vector3, yaw: float) -> void:
	var label := Label3D.new()
	label.text = "RUGBY LEGACY 27"
	label.font = load(STADIUM_FONT) as Font
	label.font_size = 48
	label.pixel_size = 0.017
	label.position = position_
	label.rotation.y = yaw
	label.modulate = Color("e5e3d5")
	label.outline_size = 0
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)


func _venue_box(size: Vector3, position_: Vector3, material: Material, basis: Basis = Basis.IDENTITY) -> void:
	var key := material.get_instance_id()
	if not _venue_batches.has(key):
		_venue_batches[key] = {"material": material, "transforms": []}
	_venue_batches[key].transforms.append(Transform3D(basis * Basis.from_scale(size), position_))


func _venue_beam(from: Vector3, to: Vector3, width: float, material: Material) -> void:
	var delta := to - from
	_venue_box(Vector3(width, delta.length(), width), (from + to) * 0.5, material, Basis(Quaternion(Vector3.UP, delta.normalized())))


func _flush_venue_boxes() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var index := 0
	for batch: Dictionary in _venue_batches.values():
		_instance_batch("VenueStructure%d" % index, cube, batch.material, batch.transforms)
		index += 1
	_venue_batches.clear()


func _instance_batch(label: String, mesh: Mesh, material: Material, transforms: Array, colors: Array[Color] = []) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = not colors.is_empty()
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i, transforms[i])
		if batch.use_colors:
			batch.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	instance.material_override = material
	# Crowd and seats are subpixel details; avoid their thousands of shadow casters.
	if label == "VenueSeats" or label.begins_with("Spectators"):
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_spectators(positions: Array[Vector3], rotations: Array[float], rng: RandomNumberGenerator) -> void:
	# Static seated silhouettes with heads/shoulders, kept outside sporting presence.
	# Three bounded MultiMeshes; no per-spectator nodes, physics or animation.
	var torsos: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var legs: Array[Transform3D] = []
	var clothes: Array[Color] = []
	var skins: Array[Color] = []
	var trousers: Array[Color] = []
	var palette := [Color("243238"), Color("567078"), Color("92968c"), Color("b4b2a4"), Color("735252"), Color("46584f"), Color("38464f")]
	var skin_palette := [Color("c09a7b"), Color("986c50"), Color("d3b398"), Color("77533f")]
	for i in positions.size():
		var height := rng.randf_range(0.88, 1.12)
		var basis := Basis().rotated(Vector3.UP, rotations[i])
		var p := positions[i]
		torsos.append(Transform3D(basis * Basis.from_scale(Vector3(0.42, 0.62 * height, 0.31)), p + Vector3(0, 0.27 * height, 0)))
		heads.append(Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.92, 1.08)), p + Vector3(0, 0.73 * height, 0)))
		legs.append(Transform3D(basis * Basis.from_scale(Vector3(0.35, 0.18, 0.58)), p + basis * Vector3(0, -0.12, 0.22)))
		clothes.append(palette[rng.randi_range(0, palette.size() - 1)])
		skins.append(skin_palette[rng.randi_range(0, skin_palette.size() - 1)])
		trousers.append(Color("293136"))
	var coloured := _material(Color.WHITE)
	coloured.vertex_color_use_as_albedo = true
	var torso := BoxMesh.new()
	torso.size = Vector3.ONE
	var head := SphereMesh.new()
	head.radius = 0.145
	head.height = 0.32
	head.radial_segments = 6
	head.rings = 3
	_instance_batch("SpectatorsTorso", torso, coloured, torsos, clothes)
	_instance_batch("SpectatorsHead", head, coloured, heads, skins)
	_instance_batch("SpectatorsSeatedLegs", torso, coloured, legs, trousers)


## Lisibilité du ballon à la distance de la caméra TV (lot 5, 16 novembre 2026) : un peu plus
## grand que nature, crème lumineux et souligné d'un contour sombre de deux pixels environ.
## Ni halo ni cercle au sol dans les vues de retransmission (choix de Léo) ; le ballon reste
## dans les mains du porteur (les mains le tiennent par ses flancs, voir match_presentation.gd).
const BALLON_LISIBLE := 1.25
const BALLON_CONTOUR := "res://shaders/ballon_contour.gdshader"

func _build_ball() -> void:
	_ball = Node3D.new()
	_ball.name = "Ball"
	add_child(_ball)
	var corps := Node3D.new()
	corps.name = "BallBody"
	corps.scale = Vector3.ONE * BALLON_LISIBLE
	_ball.add_child(corps)
	var ball := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.23
	shape.height = 0.46
	shape.radial_segments = 20
	shape.rings = 12
	ball.mesh = shape
	ball.scale = Vector3(0.87, 0.53, 0.53)
	var cuir := _material(Color("f8efcf"))
	# Légère émission : le ballon ne s'éteint pas dans l'ombre des joueurs.
	cuir.emission_enabled = true
	cuir.emission = Color("f8efcf")
	cuir.emission_energy_multiplier = 0.22
	var contour := ShaderMaterial.new()
	contour.shader = load(BALLON_CONTOUR)
	cuir.next_pass = contour
	ball.material_override = cuir
	corps.add_child(ball)
	# Original dark seams give rotation and hand contact a readable reference.
	for offset in [-0.095, 0.095]:
		var seam := MeshInstance3D.new()
		var stripe := TorusMesh.new()
		stripe.inner_radius = 0.101
		stripe.outer_radius = 0.108
		stripe.rings = 16
		stripe.ring_segments = 4
		seam.mesh = stripe
		seam.rotation.z = PI * 0.5
		seam.position.x = offset
		seam.material_override = _material(Color("263c43"))
		corps.add_child(seam)
	# A flat presentation halo keeps the small oval legible at fullfield scale.
	var halo := MeshInstance3D.new()
	_ball_marker = halo
	var ring := TorusMesh.new()
	ring.inner_radius = 0.61
	ring.outer_radius = 0.66
	ring.rings = 20
	ring.ring_segments = 6
	halo.mesh = ring
	halo.material_override = _material(Color("e9bf5a"), true)
	_ball.add_child(halo)
	_ball_beacon = Tactique.construire_balise(_ball)
	_ball.visible = false
