extends Control
## Terrain 2D de l'entracte (demande de Léo, 12 novembre 2026 : « le match continue à se
## dérouler » entre deux temps forts, comme la vue 2D des jeux de management de football).
##
## Terrain de rugby vu de dessus (100 m entre les lignes d'essai, en-buts de 10 m, 70 m de
## large, lignes 5/22/10/50 m, poteaux), trente pastilles numérotées aux couleurs des deux
## équipes et le ballon. Les positions viennent du moteur : chaque fait du journal arrive
## avec la place des trente joueurs que le moteur lui donne (`direct.deroule`, la même
## scène que la vue 3D). La vue ne fait que passer de l'une à l'autre : passe vers le
## porteur, course, regroupement, coup de pied en cloche, touche, mêlée. Aucun fait n'est
## créé ici ; entre deux faits, les mouvements de remplissage (replacement, soutien, ruck,
## respiration de la ligne) restent autour des places du moteur. La pause fige tout.
const S = preload("res://ui/contextual/skin.gd")
const T = preload("res://theme.gd")
const Charte = preload("res://ui/charte.gd")

const EN_BUT := 10.0
const LARGEUR := 70.0
## Durées de référence d'un fait (secondes réelles), raccourcies pour suivre l'horloge.
const DUREES := {"carry": 1.7, "try": 2.0, "kick": 1.9, "kickoff": 2.0, "drop22": 1.8, "goalLine": 1.8, "goal": 2.2, "miss": 2.2,
	"lineout": 2.3, "scrum": 2.3, "setpiece-win": 1.6, "setpiece-loss": 1.6, "reception": 1.4, "turnover": 1.3, "touch": 1.5,
	"penalty": 1.3, "hand-fault": 1.3, "ingoal": 1.5}
const COUPS_DE_PIED := ["kick", "kickoff", "drop22", "goalLine", "goal", "miss", "touch"]
const LIBELLES := {"carry": "Temps de jeu", "try": "Essai", "kick": "Jeu au pied", "kickoff": "Coup d’envoi", "drop22": "Renvoi aux 22",
	"goalLine": "Renvoi de l’en-but", "goal": "Tir au but", "miss": "Tir au but", "lineout": "Touche", "scrum": "Mêlée",
	"setpiece-win": "Conquête", "setpiece-loss": "Conquête perdue", "reception": "Réception", "turnover": "Ballon récupéré",
	"touch": "Sortie en touche", "penalty": "Pénalité", "hand-fault": "En-avant", "ingoal": "Dans l’en-but"}

signal fait_joue(item: Dictionary)

var equipes: Array = []
var couleurs: Array[Color] = [Charte.CLUB, Charte.IVOIRE_2]
var encres: Array[Color] = [Charte.IVOIRE, Charte.ENCRE]
## Côté du manager (anneau doré discret sur ses pastilles), -1 sinon.
var camp := -1
## Échelle de l'interface (1 en 2560×1440, 0,5 en 1280×720).
var densite := 0.5
## Secondes réelles par minute de match (horloge de l'entracte).
var cadence := 1.5
## Figé : pause du match, tiroir ouvert, ou écran masqué.
var gel := false
## Mode calme (préférence « mouvement réduit ») : pas de respiration ni de traînée.
var calme := false
## Étiquette du fait en cours en haut à gauche du terrain (l'entracte la remplace par son fil).
var legende := true
## Le terrain remplit son cadre (longueur étirée, bornée) au lieu de garder l'échelle exacte (entracte en tuiles).
var remplir := false
## Pastilles dessinées à la dernière image (clé « camp:poste » → centre) et leur rayon : survol et clic.
var centres_dessin: Dictionary = {}
var rayon_dessin := 0.0
var _survolee := ""
## Survol d'une pastille (clé « camp:poste », vide en sortant) et clic sur elle.
signal pastille_survolee(cle: String)
signal pastille_choisie(cle: String)
## Taille des pastilles (1 : terrain plein écran ; plus petit sur le terrain de l'entracte en tuiles).
var taille_pastilles := 1.0
## Plancher du rayon des pastilles en pixels ; négatif : celui du terrain plein écran (9 px, 20 px en 1440p). L'écran 2D
## du direct le met à 0 : les pastilles suivent l'échelle du terrain (jamais une masse de ronds qui se chevauchent).
var plancher_pastilles := -1.0
## Rayon sous lequel les numéros ne tiennent plus lisiblement dans la pastille : ils sont masqués (infobulle au survol).
const RAYON_NUMERO := 7.0
## Pelouse verte (écran 2D du direct, retouche de Léo du 21/11/2026) : vert gazon sobre, bandes de tonte de 10 m,
## lignes blanches nettes ; sinon, le terrain tracé en ivoire sur le panneau.
var pelouse := false
const GAZON := Color("2f6b3a")
const GAZON_TONTE := Color("357541")
## Zone de jeu et repères du moteur (essais, pénalités, cartons), pour le fond.
var direct: Dictionary = {}

## Places affichées (mètres), cibles du moteur, départs de la transition en cours.
var places: Dictionary = {}
var cibles: Dictionary = {}
var _departs: Dictionary = {}
var _phases: Dictionary = {}
var ballon := Vector2(50, 35)
var hauteur := 0.0
var _ballon_depart := Vector2(50, 35)
var possession := -1
var _file: Array = []
var _courant: Dictionary = {}
var _t := 0.0
var _duree := 1.0
var _temps := 0.0
var _trace: Array[Vector2] = []
var _regroupement: Array = []
## Dernier fait du journal mis en file (indice du moteur) et dernier fait joué.
var dernier_i := -1
var joue_i := -1
var joue: Dictionary = {}
## Journal de lecture pour les tests : faits joués, temps de vie, images.
var suivi: Array[Dictionary] = []
var images := 0
var _recaler := -2
var _items: Array = []
var _limite := 0

func px(valeur: float) -> float:
	return valeur * densite

func _ready() -> void:
	name = "MatchBetweenPitch"
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true

# --- Alimentation -------------------------------------------------------------

## Couleurs des deux équipes : la couleur du club, l'équipe qui se déplace passe en tenue
## claire si les deux se confondent (comme un maillot extérieur).
func regler_equipes(valeur: Array) -> void:
	equipes = valeur
	for cote in mini(equipes.size(), 2):
		var club: Dictionary = equipes[cote] if equipes[cote] is Dictionary else {}
		var teinte := str(club.get("presentation", {}).get("color", club.get("color", "")))
		if not teinte.is_empty(): couleurs[cote] = Color.from_string(teinte, couleurs[cote])
	if _ecart(couleurs[0], couleurs[1]) < 0.28:
		couleurs[1] = Charte.IVOIRE_2 if couleurs[0].get_luminance() < 0.6 else Charte.ENCRE_2
	for cote in 2:
		encres[cote] = Charte.ENCRE if couleurs[cote].get_luminance() > 0.55 else Charte.IVOIRE

static func _ecart(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() + absf(a.get_luminance() - b.get_luminance())

## Faits du moteur (direct.deroule). `limite` : premier indice du journal qui n'est pas encore
## montrable (temps fort retenu, action en avance du moteur) ; rien à partir de lui n'est joué.
func alimenter(items: Array, limite: int) -> void:
	_items = items
	_limite = limite
	_integrer()

func _integrer() -> void:
	var montrables: Array = []
	for item: Variant in _items:
		if item is Dictionary and int(item.get("i", -1)) < _limite and item.get("scene") is Dictionary: montrables.append(item)
	if _recaler > -2:
		# Après un temps fort (ou à l'ouverture) : on repart de la dernière image déjà vue.
		var jusque := _recaler
		_recaler = -2
		var base: Dictionary = {}
		for item: Dictionary in montrables:
			if int(item.i) <= jusque or jusque < 0: base = item
		if not base.is_empty():
			_poser(base)
			dernier_i = maxi(jusque, int(base.i))
			joue_i = int(base.i)
			joue = base
		else:
			dernier_i = jusque
		_file = _file.filter(func(f: Dictionary): return int(f.i) > dernier_i)
		_courant = {}
	for item: Dictionary in montrables:
		if int(item.i) <= dernier_i: continue
		dernier_i = int(item.i)
		_file.append(item)
	# Le terrain ne prend jamais plus d'une demi-douzaine de faits de retard sur l'horloge.
	while _file.size() > 8:
		_poser(_file.pop_front())

## Après un temps fort : le terrain reprend à l'image `indice` (dernière montrée en 3D).
## -1 : à la dernière image disponible (ouverture du match, reprise d'une sauvegarde).
func recaler(indice: int) -> void:
	_recaler = indice
	suivi.append({"evenement": "recale", "i": indice})
	if not _items.is_empty(): _integrer()

func en_retard() -> bool:
	return not _file.is_empty() or not _courant.is_empty()

## Indice du prochain fait encore à jouer (le fil s'arrête avant lui), -1 si aucun.
func prochain_i() -> int:
	if not _courant.is_empty(): return int(_courant.get("i", -1))
	if not _file.is_empty(): return int(_file[0].get("i", -1))
	return -1

## Horloge du fait que le terrain montre (en cours, sinon le dernier joué), « » si aucun.
func horloge_montree() -> String:
	var item: Dictionary = _courant if not _courant.is_empty() else joue
	return str(item.get("horloge", ""))

func file_attente() -> int:
	return _file.size() + (0 if _courant.is_empty() else 1)

static func _cle(cote: int, poste: int) -> String:
	return "%d:%d" % [cote, poste]

## Les places d'une scène sans transition (première image, retard rattrapé).
func _poser(item: Dictionary) -> void:
	var scene: Dictionary = item.get("scene", {})
	cibles = _lire(scene)
	for cle: String in places.keys():
		if not cibles.has(cle): places.erase(cle)
	for cle: String in cibles: places[cle] = cibles[cle].place
	var b: Array = scene.get("ballon", [50, 35])
	ballon = Vector2(float(b[0]), float(b[1]))
	hauteur = 0.0
	possession = int(scene.get("possession", possession))
	_trace.clear()
	_regroupement = _regroupement_autour(ballon) if str(item.get("kind", "")) in ["carry", "turnover"] else []
	joue_i = int(item.get("i", joue_i))
	joue = item
	queue_redraw()

static func _lire(scene: Dictionary) -> Dictionary:
	var resultat: Dictionary = {}
	for j: Variant in scene.get("joueurs", []):
		if not j is Array or (j as Array).size() < 5: continue
		resultat[_cle(int(j[0]), int(j[1]))] = {"cote": int(j[0]), "poste": int(j[1]), "place": Vector2(float(j[2]), float(j[3])), "vedette": int(j[4]) == 1,
			"id": str(j[5]) if (j as Array).size() > 5 else ""}
	return resultat

# --- Lecture ------------------------------------------------------------------

func _process(delta: float) -> void:
	if gel or not is_visible_in_tree(): return
	avancer(delta)

## Une image de la lecture (appelée par _process ; les tests l'appellent directement).
func avancer(delta: float) -> void:
	_temps += delta
	images += 1
	if _courant.is_empty() and not _file.is_empty(): _commencer(_file.pop_front())
	if not _courant.is_empty():
		_t += delta / maxf(0.05, _duree)
		_transition(minf(_t, 1.0))
		if _t >= 1.0: _finir()
	else:
		_vivre(delta)
	if not calme and (_trace.is_empty() or _trace[-1].distance_to(ballon) > 0.6):
		_trace.append(ballon)
		if _trace.size() > 14: _trace.remove_at(0)
	queue_redraw()

func _commencer(item: Dictionary) -> void:
	_courant = item
	_t = 0.0
	var kind := str(item.get("kind", ""))
	# Durée : celle du fait, raccourcie quand d'autres faits de la même minute attendent,
	# pour que le terrain suive l'horloge accélérée sans se laisser distancer.
	var meme_minute := 1
	for f: Dictionary in _file:
		if int(f.get("minute", -1)) <= int(item.get("minute", -1)): meme_minute += 1
	var base := float(DUREES.get(kind, 1.2))
	var budget := cadence / float(maxi(1, meme_minute)) * (0.7 if _file.size() > 3 else 1.0)
	_duree = clampf(minf(base, budget * 1.15), 0.35, base)
	_departs = places.duplicate()
	_ballon_depart = ballon
	var scene: Dictionary = item.get("scene", {})
	cibles = _lire(scene)
	possession = int(scene.get("possession", possession))
	_phases.clear()
	for cle: String in cibles:
		if not _departs.has(cle): _departs[cle] = cibles[cle].place
		_phases[cle] = float(absi(cle.hash()) % 1000) / 1000.0
	for cle: String in _departs.keys():
		if not cibles.has(cle): places.erase(cle)
	_regroupement = []
	suivi.append({"evenement": "fait", "i": int(item.get("i", -1)), "kind": kind, "duree": _duree, "temps": _temps})

func _finir() -> void:
	var item := _courant
	_transition(1.0)
	_courant = {}
	joue_i = int(item.get("i", joue_i))
	joue = item
	var kind := str(item.get("kind", ""))
	_regroupement = _regroupement_autour(ballon) if kind in ["carry", "turnover"] else []
	fait_joue.emit(item)

static func _lisse(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _vedette() -> String:
	for cle: String in cibles:
		if cibles[cle].vedette: return cle
	return ""

func _transition(t: float) -> void:
	var item := _courant
	var kind := str(item.get("kind", ""))
	var scene: Dictionary = item.get("scene", {})
	var b: Array = scene.get("ballon", [50, 35])
	var o: Array = scene.get("origine", b)
	var fin := Vector2(float(b[0]), float(b[1]))
	var depart := Vector2(float(o[0]), float(o[1]))
	var sens := 1.0 if possession == 0 else -1.0
	var vedette := _vedette()
	var demi := _cle(possession, 8)
	# Tous les joueurs : de leur place vers celle du moteur, chacun à son rythme (la défense
	# réagit un peu après l'attaque), avec une petite courbe pour ne pas glisser en ligne droite.
	for cle: String in cibles:
		var de: Vector2 = _departs.get(cle, cibles[cle].place)
		var vers: Vector2 = cibles[cle].place
		var retard: float = 0.12 * _phases.get(cle, 0.0) + (0.06 if int(cibles[cle].cote) != possession else 0.0)
		var k := _lisse((t - retard) / maxf(0.2, 0.92 - retard))
		var courbe := (vers - de).orthogonal().normalized() * sin(k * PI) * minf(1.6, de.distance_to(vers) * 0.08) * (1.0 if _phases.get(cle, 0.0) > 0.5 else -1.0)
		places[cle] = de.lerp(vers, k) + courbe
	match kind:
		"carry", "try":
			# Le demi de mêlée sort le ballon du ruck, passe au porteur qui va au contact.
			var recoit := Vector2(depart.x - sens * 4.0, lerpf(depart.y, fin.y, 0.35))
			if vedette != "" and vedette != demi:
				var de_v: Vector2 = _departs.get(vedette, recoit)
				var arrivee: Vector2 = cibles[vedette].place
				places[vedette] = de_v.lerp(recoit, _lisse(t / 0.3)) if t < 0.3 else recoit.lerp(arrivee, _lisse((t - 0.3) / (0.55 if kind == "carry" else 0.62)))
			if places.has(demi) and cibles.has(demi) and demi != vedette:
				var ruck := depart - Vector2(sens * 0.8, 0)
				places[demi] = (_departs.get(demi, ruck) as Vector2).lerp(ruck, _lisse(t / 0.15)) if t < 0.3 else ruck.lerp(cibles[demi].place, _lisse((t - 0.3) / 0.62))
			if t < 0.15: _ballon_vers(_ballon_depart.lerp(depart, _lisse(t / 0.15)), 0.0)
			elif t < 0.3: _ballon_vers(depart.lerp(recoit, (t - 0.15) / 0.15), sin((t - 0.15) / 0.15 * PI) * 1.2)
			elif vedette != "": _ballon_vers(places[vedette], 0.0)
			else: _ballon_vers(recoit.lerp(fin, (t - 0.3) / 0.7), 0.0)
			if t >= 0.92: _ballon_vers(fin, 0.0)
		"kick", "kickoff", "drop22", "goalLine", "goal", "miss", "touch":
			if vedette != "":
				var frappe: Vector2 = cibles[vedette].place
				places[vedette] = (_departs.get(vedette, frappe) as Vector2).lerp(frappe, _lisse(t / 0.2)) if t < 0.3 else frappe
			var vol := clampf((t - 0.25) / 0.55, 0.0, 1.0)
			if t < 0.25: _ballon_vers(_ballon_depart.lerp(depart, _lisse(t / 0.2)), 0.0)
			else:
				var portee := depart.distance_to(fin)
				_ballon_vers(depart.lerp(fin, vol), sin(vol * PI) * clampf(portee * (0.32 if kind in ["goal", "miss"] else 0.22), 2.0, 16.0))
		"lineout":
			# Les avants s'alignent, le talonneur lance, le sauteur capte, le demi récupère.
			var sauteur := _cle(possession, 4)
			var lanceur := _cle(int(item.get("equipe", possession)), 1)
			var bord := Vector2(fin.x, 0.0 if fin.y < 35.0 else LARGEUR)
			var capte: Vector2 = places.get(sauteur, fin + Vector2(0, 8))
			if t < 0.62: _ballon_vers(places.get(lanceur, bord), 0.0)
			elif t < 0.82: _ballon_vers(bord.lerp(capte, (t - 0.62) / 0.2), sin((t - 0.62) / 0.2 * PI) * 2.5 + 1.5)
			else: _ballon_vers(capte.lerp(places.get(demi, capte), (t - 0.82) / 0.18), 0.0)
		"scrum", "setpiece-win", "setpiece-loss":
			if t < 0.7: _ballon_vers(_ballon_depart.lerp(fin, _lisse(t / 0.4)), 0.0)
			else: _ballon_vers(fin.lerp(places.get(demi, fin), _lisse((t - 0.7) / 0.3)), 0.0)
		"reception":
			var vol := clampf(t / 0.7, 0.0, 1.0)
			_ballon_vers(depart.lerp(fin, vol), sin(vol * PI) * clampf(depart.distance_to(fin) * 0.2, 1.0, 12.0))
			if vedette != "" and t >= 0.7: _ballon_vers(places[vedette], 0.0)
		_:
			_ballon_vers(_ballon_depart.lerp(fin, _lisse(t)), 0.0)

func _ballon_vers(point: Vector2, h: float) -> void:
	ballon = point
	hauteur = maxf(0.0, h)

## Ruck : les deux plus proches de chaque équipe se lient au-dessus du ballon.
func _regroupement_autour(point: Vector2) -> Array:
	var resultat: Array = []
	for cote in 2:
		var proches: Array = []
		for cle: String in places:
			if cle.begins_with("%d:" % cote) and cle != _cle(possession, 8): proches.append([(places[cle] as Vector2).distance_to(point), cle])
		proches.sort_custom(func(a: Array, b: Array): return a[0] < b[0])
		for n in mini(2 if cote == possession else 1, proches.size()):
			if float(proches[n][0]) < 9.0: resultat.append(proches[n][1])
	return resultat

## Entre deux faits : chacun reste autour de sa place (respiration de la ligne, soutien),
## les joueurs du ruck se lient au ballon, le demi de mêlée se place derrière.
func _vivre(delta: float) -> void:
	var sens := 1.0 if possession == 0 else -1.0
	var lie := 0
	for cle: String in cibles:
		var ancre: Vector2 = cibles[cle].place
		if cle in _regroupement:
			var cote := 1.0 if cle.begins_with("%d:" % possession) else -1.0
			ancre = ballon + Vector2(-sens * cote * 0.9, (float(lie % 2) - 0.5) * 1.1)
			lie += 1
		elif cle == _cle(possession, 8) and not _regroupement.is_empty():
			ancre = ballon - Vector2(sens * 1.6, 0.4)
		var phase: float = _phases.get(cle, float(absi(cle.hash()) % 1000) / 1000.0)
		if not calme and not cle in _regroupement:
			ancre += Vector2(sin(_temps * 0.9 + phase * TAU), cos(_temps * 0.7 + phase * 5.0)) * 0.45
		places[cle] = (places.get(cle, ancre) as Vector2).lerp(ancre, clampf(delta * 2.4, 0.0, 1.0))
	if not _regroupement.is_empty(): hauteur = 0.0

# --- Survol et clic des pastilles -------------------------------------------------

## Pastille sous un point du terrain (clé « camp:poste »), vide s'il n'y en a pas.
func pastille_sous(point_local: Vector2) -> String:
	var meilleure := ""
	var proche := rayon_dessin * 1.15
	for cle: String in centres_dessin:
		var d := (centres_dessin[cle] as Vector2).distance_to(point_local)
		if d <= proche:
			proche = d
			meilleure = cle
	return meilleure

func _gui_input(event: InputEvent) -> void:
	var mouvement := event as InputEventMouseMotion
	if mouvement != null:
		var cle := pastille_sous(mouvement.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not cle.is_empty() else Control.CURSOR_ARROW
		if cle != _survolee:
			_survolee = cle
			pastille_survolee.emit(cle)
		return
	var clic := event as InputEventMouseButton
	if clic != null and clic.pressed and clic.button_index == MOUSE_BUTTON_LEFT:
		var cle := pastille_sous(clic.position)
		if not cle.is_empty():
			pastille_choisie.emit(cle)
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not _survolee.is_empty():
		_survolee = ""
		pastille_survolee.emit("")
# --- Dessin -------------------------------------------------------------------

func champ() -> Rect2:
	# Marge intérieure : une pastille posée sur une ligne de touche (y jusqu'à -2 ou 72) reste
	# entière dans le cadre, même sur un petit terrain (entracte en tableau de bord).
	var marge := maxf(9.0, px(20)) + 3.0
	var libre := size - Vector2(px(24) + 2.0 * marge, 2.0 * marge)
	libre.y *= LARGEUR / (LARGEUR + 4.0)
	var echelle := minf(libre.x / (100.0 + 2.0 * EN_BUT), libre.y / LARGEUR)
	var taille := Vector2((100.0 + 2.0 * EN_BUT) * echelle, LARGEUR * echelle)
	# Entracte : le terrain remplit sa tuile ; la longueur s'étire au plus de 40 % au-delà de l'échelle (lecture du jeu,
	# pas une mesure exacte), la hauteur suit la tuile.
	if remplir:
		var ey := libre.y / LARGEUR
		var ex := minf(libre.x / (100.0 + 2.0 * EN_BUT), ey * 1.4)
		taille = Vector2((100.0 + 2.0 * EN_BUT) * ex, LARGEUR * ey)
	return Rect2((size - taille) * 0.5, taille)

func echelle() -> float:
	return champ().size.y / LARGEUR

func point(x: float, y: float) -> Vector2:
	var c := champ()
	var e := c.size.y / LARGEUR
	var ex := c.size.x / (100.0 + 2.0 * EN_BUT)
	return c.position + Vector2((EN_BUT + clampf(x, -EN_BUT, 100.0 + EN_BUT)) * ex, clampf(y, -2.0, LARGEUR + 2.0) * e)

## Rayon des pastilles : lisible en 720p (8 px au moins), proportionné au terrain.
func rayon() -> float:
	var plancher := plancher_pastilles if plancher_pastilles >= 0.0 else maxf(9.0, px(20))
	return maxf(plancher, echelle() * 1.5 * taille_pastilles) if plancher_pastilles >= 0.0 else maxf(plancher, echelle() * 1.5) * taille_pastilles

func _draw() -> void:
	var c := champ()
	if c.size.x <= 40.0 or c.size.y <= 30.0: return
	var e := c.size.y / LARGEUR
	var police: Font = T.DISPLAY
	# Humeur « direct » de la charte : pas de pelouse verte ; le terrain est tracé en ivoire (1 px) sur le panneau,
	# en-buts compris, tirets pour les 5 m, 10 m et 15 m.
	draw_rect(c, GAZON if pelouse else Charte.FOND)
	if pelouse:
		# Bandes de tonte alternées, tous les 10 m (en-buts compris).
		var pas_x := c.size.x / (100.0 + 2.0 * EN_BUT)
		var x0 := c.position.x
		var k := 0
		while x0 < c.end.x - 0.5:
			var largeur_bande := (EN_BUT if k == 0 or x0 + 10.0 * pas_x > point(100.0, 0).x + 0.5 else 10.0) * pas_x
			if k % 2 == 1: draw_rect(Rect2(x0, c.position.y, minf(largeur_bande, c.end.x - x0), c.size.y), GAZON_TONTE)
			x0 += largeur_bande
			k += 1
	var ligne := Color(1, 1, 1, 0.95) if pelouse else Color(Charte.IVOIRE, 0.78)
	var fine := maxf(1.0, px(2)) if pelouse else 1.0
	# Zone de jeu actuelle (bande de 10 m du moteur) : un voile ivoire à peine visible.
	var zone: Dictionary = direct.get("zone", {})
	if not zone.is_empty():
		var zx := clampf(floorf(float(zone.get("x", 50.0)) / 10.0) * 10.0, 0.0, 90.0)
		draw_rect(Rect2(point(zx, 0), Vector2(10.0 * c.size.x / (100.0 + 2.0 * EN_BUT), c.size.y)), Color(Charte.IVOIRE, 0.04))
	draw_rect(c, ligne, false, fine)
	for metre in [0.0, 22.0, 50.0, 78.0, 100.0]:
		draw_line(point(metre, 0), point(metre, LARGEUR), ligne, fine)
	for metre in [5.0, 40.0, 60.0, 95.0]:
		draw_dashed_line(point(metre, 0), point(metre, LARGEUR), Color(ligne, 0.75 if pelouse else 0.5), fine, px(12))
	# Tirets des 5 m et 15 m le long des touches.
	for largeur in [5.0, 15.0, 55.0, 65.0]:
		draw_dashed_line(point(5.0, largeur), point(95.0, largeur), Color(ligne, 0.6 if pelouse else 0.35), fine, px(12))
	var corps := maxi(12, roundi(px(22)))
	for repere in [[22.0, "22"], [40.0, "10"], [60.0, "10"], [78.0, "22"]]:
		draw_string(police, point(repere[0], LARGEUR) + Vector2(px(6), -px(10)), repere[1], HORIZONTAL_ALIGNMENT_LEFT, px(80), corps, Color(1, 1, 1, 0.9) if pelouse else Color(Charte.IVOIRE, 0.75))
	# Poteaux : deux montants à 5,6 m l'un de l'autre et la barre, sur la ligne d'essai.
	for x in [0.0, 100.0]:
		draw_line(point(x, 35.0 - 2.8), point(x, 35.0 + 2.8), Charte.IVOIRE, maxf(2.0, px(5)))
	# En-buts : « EN-BUT » et le nom du club qui le défend, écrits en long.
	for cote in mini(equipes.size(), 2):
		var nom := S.G.club_name(equipes[cote]) if equipes[cote] is Dictionary else ""
		if nom.is_empty(): continue
		var centre := point(-EN_BUT * 0.5 if cote == 0 else 100.0 + EN_BUT * 0.5, 35.0)
		# Nom entier, jamais coupé : la taille baisse pour tenir dans la hauteur du terrain.
		var texte_en_but := ("En-but " + nom).to_upper()
		var corps_en_but := corps
		while corps_en_but > 10 and police.get_string_size(texte_en_but, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_en_but).x > c.size.y - 8.0: corps_en_but -= 1
		draw_set_transform(centre, -PI / 2.0 if cote == 0 else PI / 2.0)
		draw_string(police, Vector2(-c.size.y * 0.5, corps_en_but * 0.35), texte_en_but, HORIZONTAL_ALIGNMENT_CENTER, c.size.y, corps_en_but, Color(1, 1, 1, 0.92) if pelouse else Color(Charte.IVOIRE, 0.7))
		draw_set_transform(Vector2.ZERO, 0.0)
	# Essais, pénalités et cartons déjà joués : petits jalons discrets au bord du terrain.
	for repere: Dictionary in direct.get("reperes", []):
		if int(repere.get("i", -1)) > joue_i and joue_i >= 0: continue
		var equipe := clampi(int(repere.get("equipe", 0)), 0, 1)
		var kind := str(repere.get("kind", ""))
		var ou := point(clampf(float(repere.get("x", 50.0)), -4.0, 104.0), LARGEUR + 0.0) + Vector2(0, -px(14))
		if kind == "card":
			draw_rect(Rect2(ou - Vector2(px(6), px(9)), Vector2(px(12), px(18))), Charte.D if repere.get("rouge", false) else Charte.ATTRIBUT_55)
		else:
			draw_circle(ou, px(9), couleurs[equipe] if _plein(equipe) else Charte.FOND)
			draw_arc(ou, px(9), 0.0, TAU, 16, Charte.club_trait(couleurs[equipe]), maxf(1.0, px(2)), true)
	_dessiner_jeu(police, e)

## Notre équipe en pastilles pleines, l'adversaire en anneaux (la forme dit le camp, pas la seule couleur) ;
## sans camp connu, l'équipe qui reçoit est pleine.
func _plein(cote: int) -> bool:
	return cote == (camp if camp in [0, 1] else 0)

## Centres dessinés : les pastilles qui se chevauchent sont un peu écartées à l'affichage
## (numéros lisibles) ; les places du moteur (`places`) ne changent pas. Le porteur reste au ballon.
func _ecartees(ordre: Array, r: float, porteur: String) -> Dictionary:
	var centres := {}
	for cle: String in ordre: centres[cle] = point(places[cle].x, places[cle].y)
	var voulu := r * 1.9
	for passe in 6:
		for a in ordre.size():
			for b in range(a + 1, ordre.size()):
				var ca: String = ordre[a]
				var cb: String = ordre[b]
				var ecart: Vector2 = centres[cb] - centres[ca]
				var d := ecart.length()
				if d >= voulu: continue
				var sens := ecart / d if d > 0.01 else Vector2(0, 1 if (a + b) % 2 == 0 else -1)
				var pousse := (voulu - d) * 0.5
				if ca == porteur: centres[cb] += sens * pousse * 2.0
				elif cb == porteur: centres[ca] -= sens * pousse * 2.0
				else:
					centres[ca] -= sens * pousse
					centres[cb] += sens * pousse
	# Une pastille écartée au bord (ruck sur la touche) reste entière dans le cadre.
	# Cadre : le terrain lui-même, élargi d'un demi-rayon (une pastille déborde à peine de la touche).
	var cadre := champ().grow(r * 0.5)
	var bas := Vector2(maxf(cadre.position.x, r + 1.0), maxf(cadre.position.y, r + 1.0))
	var haut := Vector2(minf(cadre.end.x, size.x - r - 1.0), minf(cadre.end.y, size.y - r - 1.0))
	for cle: String in ordre: centres[cle] = (centres[cle] as Vector2).clamp(bas, haut)
	return centres

func _dessiner_jeu(police: Font, e: float) -> void:
	var r := rayon()
	# Traînée du ballon : où il vient d'aller.
	if _trace.size() >= 2:
		for n in range(1, _trace.size()):
			var a := float(n) / float(_trace.size())
			draw_line(point(_trace[n - 1].x, _trace[n - 1].y), point(_trace[n].x, _trace[n].y), Color(Charte.IVOIRE, 0.06 + 0.4 * a * a), maxf(1.0, px(3)) * (0.35 + 0.65 * a), true)
		draw_circle(point(_trace[0].x, _trace[0].y), maxf(1.5, px(4)), Color(Charte.IVOIRE, 0.2))
	var porteur := ""
	if not _courant.is_empty() or not joue.is_empty():
		var vedette := _vedette()
		if vedette != "" and hauteur < 0.3 and places.has(vedette) and (places[vedette] as Vector2).distance_to(ballon) < 1.6: porteur = vedette
	# Ombres, puis pastilles : défense dessous, attaque dessus.
	var ordre: Array = places.keys()
	ordre.sort_custom(func(a: String, b: String): return (1 if a.begins_with("%d:" % possession) else 0) < (1 if b.begins_with("%d:" % possession) else 0))
	var centres := _ecartees(ordre, r, porteur)
	centres_dessin = centres
	rayon_dessin = r
	var taille_numero := roundi(clampf(r * 1.25, 12.0, 38.0))
	for cle: String in ordre:
		var cote := int(cle.get_slice(":", 0))
		var poste := int(cle.get_slice(":", 1))
		var centre: Vector2 = centres[cle]
		var trait_club := Charte.club_trait(couleurs[cote])
		# Sur la pelouse : fin contour sombre, chaque rond se détache du vert.
		if pelouse: draw_circle(centre, r + maxf(1.0, r * 0.14), Color(0.04, 0.07, 0.06, 0.75))
		# Nous : pastille pleine aux couleurs du club, liseré clair ; eux : anneau à leur couleur sur fond sombre.
		if _plein(cote):
			draw_circle(centre, r, couleurs[cote])
			draw_arc(centre, r, 0.0, TAU, 28, trait_club, maxf(1.0, r * 0.12), true)
		else:
			draw_circle(centre, r, Charte.FOND)
			draw_arc(centre, r - maxf(1.0, r * 0.08), 0.0, TAU, 28, trait_club, maxf(1.5, r * 0.16), true)
		if cle == porteur:
			# Porteur : anneau ivoire autour de la pastille (fixe : aucun mouvement non essentiel).
			draw_arc(centre, r + maxf(2.5, r * 0.38), 0.0, TAU, 32, Charte.IVOIRE, maxf(1.5, r * 0.16), true)
		if r < RAYON_NUMERO: continue
		var numero := str(poste + 1)
		var largeur := police.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_numero).x
		var encre := encres[cote] if _plein(cote) else Charte.IVOIRE
		draw_string(police, centre + Vector2(-largeur * 0.5, taille_numero * 0.36), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_numero, encre)
	# Ballon : ovale ivoire cerclé de noir, ombre qui s'écarte quand il est en l'air.
	var sol := point(ballon.x, ballon.y)
	var leve := Vector2(0, -hauteur * e * 0.55)
	var taille := maxf(maxf(5.0, r * 0.72), px(9) if plancher_pastilles >= 0.0 else 0.0) * (1.0 + hauteur * 0.035)
	# Halo clair autour du ballon : il se repère d'un coup d'œil même au milieu d'un regroupement.
	if plancher_pastilles >= 0.0: draw_circle(sol + leve, taille * 2.3, Color(Charte.IVOIRE, 0.16))
	draw_set_transform(sol + Vector2(hauteur * e * 0.2, 0), 0.0, Vector2(1.25, 0.8))
	draw_circle(Vector2.ZERO, taille, Color(0, 0, 0, clampf(0.45 - hauteur * 0.015, 0.15, 0.45)))
	draw_set_transform(sol + leve, -0.5, Vector2(1.35, 0.9))
	draw_circle(Vector2.ZERO, taille, Charte.IVOIRE)
	draw_arc(Vector2.ZERO, taille, 0.0, TAU, 20, Charte.NUIT, maxf(1.0, taille * 0.22), true)
	draw_set_transform(Vector2.ZERO, 0.0)
	# Sens du jeu : petite flèche ivoire sous le ballon, vers l'en-but attaqué.
	if possession in [0, 1] and hauteur < 0.5:
		var sens := Vector2(1 if possession == 0 else -1, 0)
		var pied := sol + Vector2(0, r * 2.2)
		var pointe := pied + sens * r * 2.4
		draw_line(pied, pointe, Color(Charte.IVOIRE, 0.8), maxf(1.5, r * 0.2), true)
		draw_colored_polygon(PackedVector2Array([pointe + sens * r * 0.7, pointe + Vector2(0, r * 0.55), pointe - Vector2(0, r * 0.55)]), Color(Charte.IVOIRE, 0.8))
	# Fait en cours, en surimpression discrète en haut à gauche du terrain.
	var item: Dictionary = _courant if not _courant.is_empty() else joue
	if legende and not item.is_empty():
		var libelle := str(LIBELLES.get(str(item.get("kind", "")), ""))
		if str(item.get("kind", "")) == "hand-fault" and str(item.get("cause", "")) == "forward-pass": libelle = "Passe en avant"
		if str(item.get("kind", "")) == "try" and _courant.is_empty(): libelle = "Essai transformé" if item.get("transformation", false) else "Essai non transformé"
		var texte := "%s  %s" % [str(item.get("horloge", "")), libelle]
		var corps := roundi(maxf(13.0, px(26)))
		var coin := champ().position + Vector2(px(14), px(14))
		var mesure := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps)
		draw_rect(Rect2(coin, mesure + Vector2(px(24), px(14))), Color(Charte.FOND, 0.85))
		draw_string(police, coin + Vector2(px(12), mesure.y * 0.82 + px(4)), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, Charte.IVOIRE)
