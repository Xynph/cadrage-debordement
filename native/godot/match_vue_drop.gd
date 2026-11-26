extends RefCounted
## Drop (26 novembre 2026, demande de Léo) : le botteur laisse tomber le ballon qu'il tient, le
## frappe au rebond, et le ballon part vers les poteaux (entre les perches s'il est réussi, à côté
## sinon : le point visé est celui de la scène du moteur, native/engine/match-direct.cjs `drop`).
## Fonctions statiques sur la vue (`v`, NativeMatchView de match_view.gd), qui garde l'état (`_drop`).
##
## Temps (s) depuis la scène du drop : le clip « drop » part AVANT s avant sa frappe ; le ballon
## reste dans les mains jusqu'à LACHE, tombe jusqu'au sol devant le pied à FRAPPE, puis vole comme un
## tir au but (match_apres_essai.gd `vol`), depuis ce point.

const ApresEssai = preload("res://match_apres_essai.gd")
const Presentation = preload("res://match_presentation.gd")
const AVANT := 0.7
const LACHE := 0.3
const FRAPPE := 0.66
## Point de rebond : devant le pied d'appui, au ras du sol (m).
const DEVANT := 0.45
const AU_SOL := 0.12


## Le botteur `id` (à sa place, face aux poteaux) commence son drop.
static func lancer(v: NativeMatchView, id: String) -> void:
	if not v._actors.has(id):
		return
	var actor: Node3D = v._actors[id].node
	var cible: Vector3 = v._ball_target
	if Vector2(cible.x - actor.position.x, cible.z - actor.position.z).length() > 0.5:
		actor.rotation.y = atan2(cible.x - actor.position.x, cible.z - actor.position.z)
	v.jouer_geste(id, "drop", maxf(0.0, v.instant_geste("drop") - AVANT), -1.0, true)
	v._drop = {"id": id, "t": 0.0, "main": v._ball.global_position}


## Ballon du drop en cours (dans les mains, puis en chute jusqu'au rebond). Rend faux dès la frappe :
## le vol de tir au but prend la suite, depuis le point de rebond.
static func avancer(v: NativeMatchView, delta: float) -> bool:
	if v._drop.is_empty():
		return false
	var id := str(v._drop.id)
	if str(v._kind) not in ["goal", "miss"] or not v._actors.has(id):
		v._drop = {}
		return false
	v._drop.t = float(v._drop.t) + delta
	var t := float(v._drop.t)
	var entry: Dictionary = v._actors[id]
	var actor: Node3D = entry.node
	var sol := actor.position + actor.global_basis.z.normalized() * DEVANT
	sol.y = AU_SOL
	v._ball_attached = false
	if t < LACHE:
		if entry.rig:
			v._drop.main = Presentation.ball_anchor(actor, entry.rig)
		v._ball.global_position = v._drop.main
		return true
	if t < FRAPPE:
		var u := (t - LACHE) / (FRAPPE - LACHE)
		v._ball.global_position = (v._drop.main as Vector3).lerp(sol, u * u)
		return true
	# Frappe : le vol part du point de rebond.
	v._ball.global_position = sol
	v._ball_from = sol
	v._ball_travel = 0.0
	v._drop = {}
	return false
