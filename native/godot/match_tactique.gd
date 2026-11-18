extends RefCounted
## Repères de la vue tactique (caméra de dessus) : disque d'équipe avec contour contrasté et numéro
## de maillot par joueur, balise jaune autour du ballon. Présentation seule : ces nœuds ne sont
## visibles que dans la vue « tactical » ; les caméras TV et action n'en voient rien.

const NOM_REPERE := "TacticalMarker"
const NOM_BALISE := "BallBeacon"
const RAYON_DISQUE := 1.5
const RAYON_CONTOUR := 1.85
const ECHELLE_PORTEUR := 1.25
const OR_PORTEUR := Color("ffd23a")
const JAUNE_BALLON := Color("ffe000")
const ENCRE := Color("111418")


static func _materiau(couleur: Color, priorite: int = 0, devant: bool = false) -> StandardMaterial3D:
	var materiau := StandardMaterial3D.new()
	materiau.albedo_color = couleur
	materiau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiau.no_depth_test = devant
	materiau.render_priority = priorite
	return materiau


static func _disque(rayon: float, couleur: Color, y: float, nom: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = nom
	var forme := CylinderMesh.new()
	forme.top_radius = rayon
	forme.bottom_radius = rayon
	forme.height = 0.03
	forme.radial_segments = 28
	forme.rings = 1
	instance.mesh = forme
	instance.position.y = y
	instance.material_override = _materiau(couleur)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func contraste(couleur: Color) -> Color:
	return ENCRE if couleur.srgb_to_linear().get_luminance() > 0.3 else Color.WHITE


static func numero_de(joueur: Dictionary) -> int:
	if joueur.get("number") != null:
		return int(joueur.number)
	return int(joueur.get("slot", 0)) + 1


## Pose le repère sur un acteur (une seule fois, à sa création).
static func poser_repere(acteur: Node3D, joueur: Dictionary, couleur: Color) -> void:
	if acteur.get_node_or_null(NOM_REPERE) != null:
		return
	var repere := Node3D.new()
	repere.name = NOM_REPERE
	repere.visible = false
	acteur.add_child(repere)
	repere.add_child(_disque(RAYON_CONTOUR, Color.WHITE, 0.035, "Contour"))
	repere.add_child(_disque(RAYON_DISQUE, couleur, 0.06, "Disque"))
	var texte := Label3D.new()
	texte.name = "Numero"
	texte.text = str(numero_de(joueur))
	texte.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texte.no_depth_test = true
	texte.shaded = false
	texte.font_size = 96
	texte.pixel_size = 0.026
	texte.outline_size = 20
	texte.render_priority = 5
	texte.outline_render_priority = 4
	texte.position.y = 2.4
	repere.add_child(texte)
	colorer(acteur, couleur)


## Couleurs d'équipe (et contraste du contour et du numéro) ; rappelé quand le maillot change.
static func colorer(acteur: Node3D, couleur: Color) -> void:
	var repere := acteur.get_node_or_null(NOM_REPERE)
	if repere == null:
		return
	var encre := contraste(couleur)
	var disque := repere.get_node("Disque") as MeshInstance3D
	(disque.material_override as StandardMaterial3D).albedo_color = couleur
	(repere.get_node("Contour") as MeshInstance3D).set_meta("couleur", encre)
	(repere.get_node("Contour") as MeshInstance3D).material_override = _materiau(encre)
	var texte := repere.get_node("Numero") as Label3D
	texte.modulate = encre
	texte.outline_modulate = couleur


## Affiche ou masque les repères ; le porteur est agrandi et cerclé d'or.
static func mettre_a_jour(acteurs: Dictionary, porteur: String, actif: bool) -> void:
	for id: String in acteurs:
		var noeud := (acteurs[id] as Dictionary).node as Node3D
		var repere := noeud.get_node_or_null(NOM_REPERE) as Node3D
		if repere == null:
			continue
		repere.visible = actif
		if not actif:
			continue
		var tient := id == porteur
		repere.scale = Vector3.ONE * (ECHELLE_PORTEUR if tient else 1.0)
		var contour := repere.get_node("Contour") as MeshInstance3D
		var couleur: Color = OR_PORTEUR if tient else contour.get_meta("couleur", Color.WHITE)
		(contour.material_override as StandardMaterial3D).albedo_color = couleur


## Balise du ballon : anneau jaune vif cerclé de sombre et point central, toujours dessus.
static func construire_balise(ballon: Node3D) -> Node3D:
	var balise := Node3D.new()
	balise.name = NOM_BALISE
	balise.visible = false
	balise.position.y = 3.0
	var sombre := MeshInstance3D.new()
	var tore_sombre := TorusMesh.new()
	tore_sombre.inner_radius = 1.95
	tore_sombre.outer_radius = 2.85
	tore_sombre.rings = 28
	tore_sombre.ring_segments = 8
	sombre.mesh = tore_sombre
	sombre.material_override = _materiau(ENCRE, 20, true)
	balise.add_child(sombre)
	var jaune := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 2.1
	tore.outer_radius = 2.7
	tore.rings = 28
	tore.ring_segments = 8
	jaune.mesh = tore
	jaune.material_override = _materiau(JAUNE_BALLON, 21, true)
	balise.add_child(jaune)
	var point_sombre := MeshInstance3D.new()
	var bille_sombre := SphereMesh.new()
	bille_sombre.radius = 0.75
	bille_sombre.height = 1.5
	point_sombre.mesh = bille_sombre
	point_sombre.material_override = _materiau(ENCRE, 22, true)
	balise.add_child(point_sombre)
	var point := MeshInstance3D.new()
	var bille := SphereMesh.new()
	bille.radius = 0.55
	bille.height = 1.1
	point.mesh = bille
	point.material_override = _materiau(JAUNE_BALLON, 23, true)
	balise.add_child(point)
	for enfant in balise.get_children():
		(enfant as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ballon.add_child(balise)
	return balise
