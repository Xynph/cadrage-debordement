class_name NativeMatchView
extends Node3D
## Projection de présentation du moteur historique. Aucune règle ni physique ici.
## Adapter source : x 0..100 / y 0..70 -> x -50..50 / z -35..35.

const ATHLETE := "res://assets/match3d/quaternius-rugby-athlete.glb"
const BLEND_SECONDS := 0.55
const ClubPresentation = preload("res://ui/game_skin.gd")
const Presentation = preload("res://match_presentation.gd")
const Motion = preload("res://match_motion.gd")
const Kit = preload("res://match_kit.gd")
const Athlete = preload("res://match_athlete.gd")
const JoueurV5 = preload("res://match_joueur_v5.gd")
const Contact = preload("res://match_contact.gd")
const Cut = preload("res://match_cut.gd")
const Pass = preload("res://match_pass.gd")
const Gestes = preload("res://match_gestes.gd")
const Rendu = preload("res://match_rendu.gd")
const Animations = preload("res://match_animations.gd")
const Choregraphie = preload("res://match_choregraphie.gd")
const Formations = preload("res://match_formations.gd")
const Impacts = preload("res://match_impacts.gd")
const ChutePhysique = preload("res://match_chute_physique.gd")
const Plancher = preload("res://match_plancher.gd")
const Tactique = preload("res://match_tactique.gd")
const ApresEssai = preload("res://match_apres_essai.gd")
const Rejeu = preload("res://match_rejeu.gd")
const VueCamera = preload("res://match_vue_camera.gd")
const VueVisee = preload("res://match_vue_visee.gd")
const VueJoueurs = preload("res://match_vue_joueurs.gd")
const VueBallon = preload("res://match_vue_ballon.gd")
const VueStade = preload("res://match_vue_stade.gd")
const CUT_SECONDS := 0.30
## Réglages de la caméra (match_vue_camera.gd), des poteaux (match_vue_visee.gd) et de la sortie vers le
## tunnel (match_vue_joueurs.gd), décrits là-bas : repris ici pour la régie, le cadrage et les tests.
const TV_OFFSET := VueCamera.TV_OFFSET
const ACTION_OFFSET := VueCamera.ACTION_OFFSET
const INCLINAISON_MAX := VueCamera.INCLINAISON_MAX
const INCLINAISON_TV_MAX := VueCamera.INCLINAISON_TV_MAX
const PLONGEE_MAX := VueCamera.PLONGEE_MAX
const PLONGEE_TV_MAX := VueCamera.PLONGEE_TV_MAX
const TV_TAILLE := VueCamera.TV_TAILLE
const ACTION_TAILLE := VueCamera.ACTION_TAILLE
const PLAN_LARGE_OFFSET := VueCamera.PLAN_LARGE_OFFSET
const PLAN_LARGE_VISE := VueCamera.PLAN_LARGE_VISE
const PLAN_LARGE_RECUL := VueCamera.PLAN_LARGE_RECUL
const PLAN_LARGE_CHAMP := VueCamera.PLAN_LARGE_CHAMP
const PLAN_SORTIE_RECUL := VueCamera.PLAN_SORTIE_RECUL
const PLAN_SORTIE_CHAMP := VueCamera.PLAN_SORTIE_CHAMP
const TERRAIN := VueCamera.TERRAIN
const BORD_HAUT := VueCamera.BORD_HAUT
const RETARD_MAX := VueCamera.RETARD_MAX
const POTEAUX_X := VueVisee.POTEAUX_X
const POTEAUX_Z := VueVisee.POTEAUX_Z
const BARRE_Y := VueVisee.BARRE_Y
const CONTOURNEMENT_MAX := VueVisee.CONTOURNEMENT_MAX
const PIVOT_MAX := VueVisee.PIVOT_MAX
const TUNNEL := VueJoueurs.TUNNEL
const ALLURE_SORTIE := VueJoueurs.ALLURE_SORTIE
const SORTIE_PROCHE_MAX := VueJoueurs.SORTIE_PROCHE_MAX
const SORTIE_PROCHE_Z := VueJoueurs.SORTIE_PROCHE_Z

## Plafonds de la caméra courante (TV ou contact).
func inclinaison_max() -> float:
	return INCLINAISON_MAX if _camera_mode == "action" else INCLINAISON_TV_MAX

func plongee_max() -> float:
	return PLONGEE_MAX if _camera_mode == "action" else PLONGEE_TV_MAX
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
## Durée réelle (s, avant ralenti) de la dernière image animée par la vue : la régie, qui passe
## avant la vue dans chaque image, mesure les déplacements de l'image précédente sur cette durée.
var dernier_delta := 0.0
## Sortie des joueurs en cours (mi-temps, fin de match) : jusqu'à la prochaine image du moteur.
var sortie := false
## Sortie montrée de près (joueurs rapprochés du tunnel, plan qui suit le groupe) et point visé.
var plan_sortie := false
var _sortie_vise := Vector3.ZERO
## Ralenti de l'essai (match_rejeu.gd) : enregistrement des poses montrées, puis lecture au ralenti
## sous un autre angle pendant laquelle la vue est suspendue ; `rejeu_fini` à sa fin (ou abrégé).
signal rejeu_fini
var _rejeu: RefCounted = Rejeu.new(self)
## Essai CD_ESSAI_PLAQUAGES (B ou C) : chute physique partielle au plaquage ; null sans la variable.
var _chute_physique: RefCounted = ChutePhysique.new(self)
## Plancher : aucune partie du corps sous la pelouse (dernière pose de l'image, match_plancher.gd).
var _plancher: RefCounted = Plancher.new()


func set_club_identity(club: Dictionary) -> void:
	var identity: Dictionary = ClubPresentation.identity(club)
	var key := JSON.stringify([identity.get("logoPath", club.get("logoPath", "")), identity.get("slug", "")])
	if key == _club_identity_key:
		return
	_club_identity_key = key
	# Same priority as the UI: pack crest, official badge, else the club's recoloured
	# crest with its initials (rendered from the interface control, never a grey shield).
	_club_crest = ClubPresentation.crest_surface_texture(club)
	if is_instance_valid(_club_branding):
		VueStade._update_club_branding(self)


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
	VueStade._build_environment(self)
	VueStade._build_ground(self)
	VueStade._build_stadium(self)
	VueStade._flush_venue_boxes(self)
	_players = Node3D.new()
	_players.name = "Players"
	add_child(_players)
	VueStade._build_ball(self)
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
	# Ambiance décorative (match_ambiance.gd) : foule vivante, confettis et fumigènes à l'essai, pluie.
	_ambiance = Ambiance.new()
	add_child(_ambiance)
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
		VueBallon._stop_live_pass(self)
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
	VueBallon._stop_live_pass(self)
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
	# Une nouvelle image venue de la régie ou du direct met fin aux pistes en cours (et à la sortie),
	# et au ralenti de l'essai (état d'avant remis d'abord).
	finir_rejeu()
	arreter_choregraphie()
	if plan_sortie:
		_camera_cut = true
	sortie = false
	plan_sortie = false
	foule.observer(live) # Public : l'image montrée (22 mètres, essai, arrêt de jeu).
	_ambiance.observer(live) # Météo annoncée par le moteur : pluie décorative.
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
		JoueurV5.vider_palette()
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
	# Sortie de mêlée : le ballon reste dans les mains du demi qui ramasse (ou du n° 8 détaché), au
	# lieu de partir seul vers le point du fait, loin du paquet (match_formations.gd, DEMI_SORTIE).
	if has_ball:
		_carrier_id = _formations.porteur(_carrier_id)
	var play_action := (_action_motion and not _paused and has_ball and _ball.visible
		and not _action_key.is_empty() and not key.is_empty())
	_action_key = key
	if not play_action or new_action:
		VueBallon._stop_live_pass(self)
		_pass_plan = Pass.plan(scene) if play_action and _kind == "carry" else {}
		_pass_elapsed = 0.0
	_contact_plan = Contact.plan(scene) if not _paused and has_ball else {}
	# Le plaqueur mis en scène (match_impacts.gd) est posé à sa place de contact dans la scène
	# projetée : il arrive encore en courant, il n'empêche pas le crochet déclaré en début de course.
	var plaqueur_en_course: bool = (_impacts.phase == "course"
		and str(_contact_plan.get("opponent", "")) == _impacts.plaqueur)
	var cut_allowed := (_action_motion and not _paused and _kind == "carry" and has_ball
		and (_contact_plan.is_empty() or plaqueur_en_course) and _pass_plan.is_empty())
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
			_actors[id] = VueJoueurs._make_actor(self, id, side, target, int(player.get("slot", -1)))
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
			VueBallon._stage_live_pass(self)
		elif not _actors.has(_pass_plan.passer) or not _actors.has(_pass_plan.receiver):
			VueBallon._stop_live_pass(self)
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
		VueJoueurs._gestes_du_fait(self, scene, previous_kind)
	VueJoueurs._replacer_longs(self, new_action)


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


## Régie des temps forts : mi-temps ou fin de match, plus rien à rejouer.
func set_plan_large(on: bool) -> void:
	if on:
		finir_rejeu()
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


## Ralenti de l'essai (régie des temps forts) : enregistrer les poses montrées pendant ce temps fort.
func enregistrer_rejeu(on: bool) -> void:
	finir_rejeu()
	_rejeu.activer(on)


## Essai aplati à l'écran : la fenêtre du ralenti se cale sur cet instant (faux sans enregistrement).
func reperer_rejeu() -> bool:
	return _rejeu.reperer()


## Rejoue la fin de l'action au ralenti (`vitesse` : part de la vitesse réelle), sous l'angle du
## ralenti. Faux sans fenêtre enregistrée, en vue de dessus, au plan large ou pendant la sortie.
func commencer_rejeu(vitesse: float = Rejeu.VITESSE) -> bool:
	if not is_node_ready() or _camera_mode == "tactical" or _plan_large or sortie:
		return false
	# Poses de présentation retirées avant la capture de l'état d'avant (remis à la fin), puis reposées.
	for id: String in _actors:
		_plancher.restaurer(id, _actors[id])
	_chute_physique.annuler()
	var lance: bool = _rejeu.commencer(vitesse)
	_poser_plancher()
	return lance


func rejeu_actif() -> bool:
	return _rejeu.actif


## Abrège le ralenti : l'état d'avant est remis aussitôt.
func finir_rejeu() -> void:
	if not _rejeu.actif:
		return
	_rejeu.finir()
	# État d'avant remis (sans plancher) : le plancher repart de lui.
	_plancher.oublier()
	_poser_plancher()
	rejeu_fini.emit()


## Figurant (arbitre) enregistré et figé avec les joueurs pendant le ralenti.
func inscrire_rejeu(noeud: Node3D, modele: Node3D, squelette: Skeleton3D) -> void:
	_rejeu.inscrire(noeud, modele, squelette)


## Contrôles du ralenti (régie, tests, match filmé).
func rejeu_etat() -> Dictionary:
	return {"actif": _rejeu.actif, "lecture": _rejeu.lecture, "duree_source": _rejeu.duree_source, "vitesse": _rejeu.vitesse,
		"ecoule": _rejeu.ecoule, "hauteur_camera": _rejeu.hauteur_camera, "gene_angle": _rejeu.gene_angle, "retrait": _rejeu._retrait, "ecart_restitution": _rejeu.ecart_restitution,
		"enregistre": _rejeu.enregistre, "poses": _rejeu.tampon.size(), "fenetre": _rejeu.clip.size()}

## Mi-temps, fin de match : marche vers le tunnel (match_vue_joueurs.gd).
func sortir_du_terrain(rapprocher: bool = false) -> void:
	VueJoueurs.sortir_du_terrain(self, rapprocher)


static func place_de_sortie(depuis: Vector3, camp: int) -> Vector3:
	return VueJoueurs.place_de_sortie(depuis, camp)


func set_camera(mode: String) -> void:
	var selected := mode if mode in ["tactical", "action"] else "tv"
	var changed := selected != _camera_mode
	# Changement de caméra pendant le ralenti : il est abrégé (la vue reprend sous la caméra choisie).
	if changed:
		finir_rejeu()
	_camera_mode = selected
	if is_instance_valid(_camera) and (changed or not _camera_framed):
		_fit_camera(0.0, true)
	if _rendu:
		_rendu.appliquer()


func _process(delta: float) -> void:
	dernier_delta = delta
	_animer_foule(delta) # Le public vit en temps réel, même pendant le ralenti.
	if _rejeu.actif:
		_chute_physique.annuler()
		# Ralenti de l'essai rejoué : la vue est suspendue, seules les poses enregistrées sont montrées ;
		# à sa fin, l'état d'avant est remis tel quel. Le plancher vaut aussi pour les poses rejouées
		# (interpolées entre deux images enregistrées).
		for id: String in _actors:
			_plancher.restaurer(id, _actors[id])
		var encore: bool = _rejeu.lire(delta)
		_poser_plancher()
		if not encore:
			rejeu_fini.emit()
		return
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
		VueJoueurs.animer_acteur(self, id, entry, delta, preparation)
	_impacts.avancer(delta)
	VueBallon._update_contact(self, delta)
	# Poses des pistes avant le ballon : les mains du porteur sont à leur place quand il y est mis.
	if choregraphie_active():
		_choregraphie.pose()
	# Chute physique du plaqué : après les poses du corps, avant le ballon (il suit les mains).
	_chute_physique.poser(delta)
	VueBallon._update_ball(self, delta)
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
				VueBallon._porter_ballon(self, id, entry, delta)
		elif rig:
			VueBallon._bras_hors_ballon(self, id, entry)
	_impacts.poser_ballon()
	if not _pass_plan.is_empty() and _pass_elapsed >= _pass_plan.duration:
		VueBallon._stop_live_pass(self, true)
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
	# Poses définitives de l'image : enregistrées pour le ralenti de l'essai (une coupe le recommence).
	# Plancher : dernière pose de l'image (après le ballon et les formations), enregistrée par le rejeu.
	_poser_plancher()
	# Puis les jambes des joueurs debout sortent du corps des joueurs couchés (ruck), à l'horizontale.
	_plancher.degager(_actors, delta, _carrier_id, _ball if _ball_attached and _ball.visible else null)
	# Et les joueurs debout ne se traversent plus entre eux (sauf mêlée et ballon porté, liés exprès).
	_plancher.separer(_actors, delta, _lies(), _carrier_id, _ball if _ball_attached and _ball.visible else null)
	_rejeu.enregistrer(delta, _camera_cut)
	_fit_camera(delta, _camera_cut)
	_camera_cut = false

## Joueurs liés dans une mêlée ou un ballon porté (contact voulu) : la séparation les laisse.
func _lies() -> Dictionary:
	var lies := {}
	if _formations != null and _formations.active() and str(_formations.formation.type) in ["melee", "sortie_melee"]:
		for id: String in _formations.formation.places:
			lies[id] = true
	var scene_gestes: RefCounted = mise_en_scene()
	if str(scene_gestes.get("phase")) in ["maul", "essai_maul"]:
		for id: String in _actors:
			if scene_gestes.stages(id):
				lies[id] = true
	if choregraphie_active():
		for id: String in _actors:
			if _choregraphie.stages(id) and str(_choregraphie.etat(id)) in ["melee", "maul"]:
				lies[id] = true
	return lies


## Plancher de tous les joueurs (match_plancher.gd) ; le ballon tenu suit les mains relevées.
func _poser_plancher() -> void:
	for id: String in _actors:
		var tenu: bool = _ball_attached and id == _carrier_id and _actors[id].rig != null
		var mains := Plancher.mains(_actors[id].rig) if tenu else Vector3.ZERO
		_plancher.poser(id, _actors[id])
		if tenu:
			_ball.global_position += Plancher.mains(_actors[id].rig) - mains


func _is_pass_player(id: String) -> bool:
	return not _pass_plan.is_empty() and (id == _pass_plan.passer or id == _pass_plan.receiver)


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


## Caméra suivie (match_vue_camera.gd).
func _fit_camera(delta: float = 0.0, cut: bool = false) -> void:
	VueCamera._fit_camera(self, delta, cut)


func offset_suivi(base: Vector3, profondeur: float, largeur: float = NAN) -> Vector3:
	return VueCamera.offset_suivi(self, base, profondeur, largeur)


func pose_camera(look: Vector3, size: float, offset: Vector3) -> Array:
	return VueCamera.pose_camera(self, look, size, offset)


## Bornes de visée et poteaux (match_vue_visee.gd).
func borner_pivot(look: Vector3, offset: Vector3, suivi: Vector3) -> Vector3:
	return VueVisee.borner_pivot(look, offset, suivi)


func borner_visee(look: Vector3, limites: Vector2 = VueVisee.VISEE_GESTE) -> Vector3:
	return VueVisee.borner_visee(look, limites)


func poteau_entre(depart: Vector3, arrivee: Vector3, m: float = VueVisee.POTEAU_MARGE) -> bool:
	return VueVisee.poteau_entre(depart, arrivee, m)


func poteau_masque(look: Vector3, size: float, offset: Vector3, marge: float = VueVisee.POTEAU_MARGE) -> bool:
	return VueVisee.poteau_masque(self, look, size, offset, marge)


func contournement_poteaux(look: Vector3, size: float, offset: Vector3) -> float:
	return VueVisee.contournement_poteaux(self, look, size, offset)


func poteau_premier_plan(look: Vector3, size: float, offset: Vector3, relache: float = 0.0) -> bool:
	return VueVisee.poteau_premier_plan(self, look, size, offset, relache)


func regroupement() -> Array[Vector3]:
	return VueVisee.regroupement(self)


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

## Joueurs (match_vue_joueurs.gd) : aussi utilisés par l'arbitre et le chorégraphe.
func _model_bounds(node: Node3D, origin: Node3D) -> AABB:
	return VueJoueurs._model_bounds(node, origin)


func _find_animation(node: Node) -> AnimationPlayer:
	return VueJoueurs._find_animation(node)


func _refresh_kits() -> void:
	_kits = Kit.resolve(_team_colors)


func alternative_kit_colors() -> Array[Color]:
	if _kits.size() != 2 or _kits[1].shirt == _team_colors[1]:
		return []
	return [_kits[0].shirt, _kits[1].shirt]


func _recolor(model: Node3D, side: int) -> void:
	if model.has_meta("joueur_v5"):
		JoueurV5.habiller(model, _kits[side])
		return
	Athlete.dress(model, _kits[side], str(model.get_meta("athlete_id", "")))


## Public du stade (19/11/2026) : état de la foule tiré des images montrées, rendu par les matières
## des spectateurs. Parts de tribus et de tenues aux couleurs des clubs.
const FOULE_SHADER := "res://shaders/foule.gdshader"
const Foule = preload("res://match_foule.gd")
var foule: Foule = Foule.new()
## Composition du public construite (contrôle, tests) : spectateurs par tribu, tenues aux couleurs.
var foule_compte := {"total": 0, "domicile": 0, "visiteurs": 0, "neutres": 0, "tenues": 0}
## Têtes des spectateurs (repère de la vue), gardées pour les contrôles de cadrage : le pilote
## graphique factice (--headless) ne conserve pas les transformations des MultiMesh.
var foule_tetes := PackedVector3Array()
var _foule_matieres: Array[ShaderMaterial] = []
const Ambiance = preload("res://match_ambiance.gd")
var _ambiance: Ambiance
## Posé par la régie des temps forts : plan d'essai joué, essai pas encore aplati à l'écran.
var essai_attendu_regie := false


func _animer_foule(delta: float) -> void:
	# Le plan de l'essai arrive avant la course : le public explose à l'aplati montré, pas avant
	# (geste d'essai de la vue, ou plan d'essai des temps forts pas encore légendé).
	foule.essai_suspendu = essai_attendu_regie or not essai_aplati()
	foule.avancer(delta)
	for matiere in _foule_matieres:
		matiere.set_shader_parameter("debout", Vector3(foule.debout[0], foule.debout[1], foule.debout[2]))
		matiere.set_shader_parameter("bras", Vector3(foule.bras[0], foule.bras[1], foule.bras[2]))
		matiere.set_shader_parameter("agitation", foule.intensite)
		matiere.set_shader_parameter("couleur_domicile", _team_colors[0])
		matiere.set_shader_parameter("couleur_exterieur", _team_colors[1])
