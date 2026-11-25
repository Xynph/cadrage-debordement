extends RefCounted
## Joueurs 3D v5 (25/11/2026, choix de Léo) : dix gabarits CC0 construits sur le squelette Quaternius
## (mêmes os, mêmes clips Man_*), 156 peaux sur un même dépliage, trois coupes à teinter.
## Gabarit choisi par le poste (slot 0..14 = n° 1..15) ; le moteur ne connaît ni la taille ni le poids
## des joueurs : chacun prend la taille de son gabarit (taille_m du manifeste). Apparence (peau, coupe)
## tirée de l'identifiant, stable d'un match à l'autre. Aucune règle ni décision sportive ici.
## Sans assets/match3d/joueurs/joueurs.json, la vue garde l'ancien athlète (match_athlete.gd).

const Athlete = preload("res://match_athlete.gd")
const DOSSIER := "res://assets/match3d/joueurs/"
const MANIFESTE := DOSSIER + "joueurs.json"
## Gabarit par poste, slot 0 = n° 1. Le n° 15 : ailier ou ouvreur selon l'identifiant.
const GABARIT_PAR_SLOT := ["prop-trapu", "prop-talon", "prop-grand", "lock-long", "lock-long",
	"flank-7", "flank-7", "flank-8", "back-demi", "back-ouvreur", "back-ailier", "back-centre",
	"back-centre", "back-ailier", ""]
const ARRIERE := ["back-ailier", "back-ouvreur"]
## Répartition des carnations (poids sur 100), toutes présentes ; teinte moyenne mesurée sur les peaux.
## Les règles des tenues (match_kit.gd) gardent Athlete.SKINS : chaque teinte ci-dessous en est à moins
## de 0,14 en RVB (contrôlé par tests/godot-match-joueurs-v5.gd).
const TEINTES := [["pale", 20], ["claire", 27], ["mate", 15], ["olive", 12], ["metisse", 10], ["foncee", 9], ["ebene", 7]]
const TEINTES_RVB := ["d9ab8f", "d3a080", "b17e60", "a27355", "774b32", "583625", "472c1f"]
## Crâne : cheveux sous une coupe, rasé, dégarni, chauve.
const CRANES := [["cheveux", 55], ["rase", 25], ["degarni", 10], ["chauve", 10]]
const COUPES := ["court", "dessus", "brosse"]
## Échelle de l'ancien athlète à 1,90 m (1,9 / 4,841 unités) : les paliers de locomotion
## (match_animations.gd) et les allures des clips d'origine sont calés dessus. Os des jambes au même
## endroit dans le squelette : la foulée d'un gabarit = son échelle / celle-ci.
const ECHELLE_REFERENCE := 1.9 / 4.841252
const TISSUS := ["Shirt2", "Shirt", "ShirtHoop", "Collar", "Pants", "Socks", "SockTurn", "Shoes", "Sole"]

static var _catalogue: Dictionary = {}
static var _lu := false
static var _scenes: Dictionary = {}
static var _textures: Dictionary = {}
static var _materiaux: Dictionary = {}


static func disponible() -> bool:
	return not catalogue().is_empty()


## Manifeste lu une fois. Il ne compte que si chaque gabarit qu'il nomme est une ressource importée :
## manifeste copié sans import Godot (ou GLB manquant), la vue garde l'ancien athlète, sans erreur
## de chargement.
static func catalogue() -> Dictionary:
	if not _lu:
		_lu = true
		if FileAccess.file_exists(MANIFESTE):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTE))
			if data is Dictionary and (data as Dictionary).get("profils") is Dictionary and (data as Dictionary).get("peaux") is Array and _gabarits_importes((data as Dictionary).profils):
				_catalogue = data
	return _catalogue


static func _fichier(profil: String, fiche: Dictionary) -> String:
	return DOSSIER + str(fiche.get("fichier", "joueur-" + profil + ".glb"))


static func _gabarits_importes(profils: Dictionary) -> bool:
	for profil: String in GABARIT_PAR_SLOT + ARRIERE:
		if not profil.is_empty() and not (profils.get(profil) is Dictionary and ResourceLoader.exists(_fichier(profil, profils[profil]), "PackedScene")):
			return false
	return true


static func _tirage(id: String, sel: String) -> int:
	return Athlete.stable_identity(id + ":" + sel)


static func _pondere(table: Array, valeur: int) -> String:
	var total := 0
	for ligne: Array in table:
		total += int(ligne[1])
	var t := valeur % total
	for ligne: Array in table:
		t -= int(ligne[1])
		if t < 0:
			return str(ligne[0])
	return str(table[-1][0])


## Gabarit d'un joueur selon son poste (slot hors 0..14 : arrière de ligne, ailier).
static func profil_pour(id: String, slot: int) -> String:
	if slot < 0 or slot >= GABARIT_PAR_SLOT.size():
		return "back-ailier"
	var profil: String = GABARIT_PAR_SLOT[slot]
	if profil.is_empty():
		profil = ARRIERE[_tirage(id, "arriere") % ARRIERE.size()]
	return profil


static func taille(profil: String) -> float:
	return float((catalogue().profils as Dictionary).get(profil, {}).get("taille_m", 1.85))


static func scene(profil: String) -> PackedScene:
	if not _scenes.has(profil):
		var fiche: Dictionary = (catalogue().profils as Dictionary).get(profil, {})
		var chemin := _fichier(profil, fiche)
		_scenes[profil] = load(chemin) as PackedScene if ResourceLoader.exists(chemin, "PackedScene") else null
	return _scenes[profil]


## Apparence stable : peau (teinte, couleur de cheveux, crâne, barbe) et coupe visible ("" si aucune).
static func apparence(id: String) -> Dictionary:
	var peaux: Array = catalogue().get("peaux", [])
	var teinte := _pondere(TEINTES, _tirage(id, "teinte"))
	var crane := _pondere(CRANES, _tirage(id, "crane"))
	var choix: Array = []
	for nom: String in peaux:
		if nom.begins_with("peau-" + teinte + "-") and nom.split("-")[3] == crane:
			choix.append(nom)
	if choix.is_empty():
		for nom: String in peaux:
			if nom.begins_with("peau-" + teinte + "-"):
				choix.append(nom)
	if choix.is_empty():
		choix = peaux
	var peau := str(choix[_tirage(id, "peau") % choix.size()])
	var parts := peau.get_basename().split("-")
	var cheveux: String = parts[2] if parts.size() > 2 else "noir"
	crane = parts[3] if parts.size() > 3 else "rase"
	var coupe: String = COUPES[_tirage(id, "coupe") % COUPES.size()] if crane == "cheveux" else ""
	var couleur := Color(str((catalogue().get("couleurs_cheveux", {}) as Dictionary).get(cheveux, "#2c1d14")))
	return {"peau": peau, "teinte": teinte, "cheveux": cheveux, "crane": crane,
		"barbe": int(parts[4]) if parts.size() > 4 else 0, "coupe": coupe, "couleur_cheveux": couleur}


## Transformation d'un nœud dans le repère d'un ancêtre (sans passer par l'arbre de scène).
static func _relatif(node: Node3D, origine: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != origine:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## Hauteur de repos du corps (sans cheveux), dans le repère du modèle : le maillage skinné est lu par
## la liaison d'un os (les nœuds du GLB portent l'échelle ×100 de l'armature, pas le maillage).
static func bornes_corps(model: Node3D) -> AABB:
	var corps := model.find_child("Corps", true, false) as MeshInstance3D
	if corps == null:
		return AABB()
	var squelette := corps.get_node_or_null(corps.skeleton) as Skeleton3D
	if corps.skin == null or squelette == null or corps.skin.get_bind_count() == 0:
		return _relatif(corps, model) * corps.get_aabb()
	var os := squelette.find_bone(str(corps.skin.get_bind_name(0)))
	var liaison := _relatif(squelette, model) * squelette.get_bone_global_rest(os) * corps.skin.get_bind_pose(0)
	return liaison * corps.get_aabb()


## Met le modèle à la taille du joueur (mètres, pieds au sol) ; renvoie la foulée relative.
static func calibrer(model: Node3D, taille_m: float) -> float:
	var bornes := bornes_corps(model)
	if bornes.size.y <= 0.001:
		return 1.0
	var echelle := taille_m / bornes.size.y
	model.scale = Vector3.ONE * echelle
	model.position.y = -bornes.position.y * echelle
	return echelle / ECHELLE_REFERENCE


## Peau et coupe du joueur : une seule coupe visible au plus, teintée à la couleur de ses cheveux.
static func appliquer_apparence(model: Node3D, look: Dictionary) -> void:
	for coupe: String in COUPES:
		var cheveux := model.find_child("Cheveux_" + coupe, true, false) as MeshInstance3D
		if cheveux == null:
			continue
		cheveux.visible = coupe == look.coupe
		if cheveux.visible:
			var source := cheveux.mesh.surface_get_material(0)
			var cle := "cheveux|" + coupe + "|" + (look.couleur_cheveux as Color).to_html()
			if not _materiaux.has(cle):
				var m := (source.duplicate() if source is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
				m.albedo_color = look.couleur_cheveux
				m.roughness = 0.92
				_materiaux[cle] = m
			cheveux.set_surface_override_material(0, _materiaux[cle])
	var corps := model.find_child("Corps", true, false) as MeshInstance3D
	if corps == null:
		return
	for i in corps.mesh.get_surface_count():
		var source := corps.mesh.surface_get_material(i)
		if source == null or source.resource_name != "Skin":
			continue
		var cle := "peau|" + str(look.peau)
		# Peau non importée : la peau d'origine du gabarit reste.
		if _texture(str(look.peau)) == null:
			continue
		if not _materiaux.has(cle):
			var m := (source.duplicate() if source is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
			m.albedo_texture = _texture(str(look.peau))
			m.albedo_color = Color.WHITE
			m.roughness = 0.62
			_materiaux[cle] = m
		corps.set_surface_override_material(i, _materiaux[cle])


static func _texture(peau: String) -> Texture2D:
	if not _textures.has(peau):
		var chemin := DOSSIER + "peaux/" + peau
		_textures[peau] = load(chemin) as Texture2D if ResourceLoader.exists(chemin, "Texture2D") else null
	return _textures[peau]


## Couleur de chaque matériau de la tenue (mêmes règles que l'ancien shader athlete_kit).
static func couleurs_tenue(kit: Dictionary) -> Dictionary:
	var maillot: Color = kit.shirt
	var detail: Color = kit.detail
	return {"Shirt2": maillot, "ShirtHoop": maillot, "Shirt": maillot.darkened(0.16), "Collar": detail,
		"SockTurn": detail, "Pants": kit.get("shorts", Color("202b35")), "Socks": maillot,
		"Shoes": Color(0.032, 0.043, 0.048), "Sole": Color("d9d6cf")}


## Tenue du club : matériaux partagés par club (cache), peau et coupe gardées.
static func habiller(model: Node3D, kit: Dictionary) -> void:
	var couleurs := couleurs_tenue(kit)
	var cle_kit := ""
	for nom: String in TISSUS:
		cle_kit += (couleurs[nom] as Color).to_html()
	var corps := model.find_child("Corps", true, false) as MeshInstance3D
	if corps == null:
		return
	for i in corps.mesh.get_surface_count():
		var source := corps.mesh.surface_get_material(i)
		if source == null or not couleurs.has(source.resource_name):
			continue
		var cle := "tenue|" + cle_kit + "|" + source.resource_name
		if not _materiaux.has(cle):
			var m := (source.duplicate() if source is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
			m.albedo_color = couleurs[source.resource_name]
			m.albedo_texture = null
			# Matière : tissu mat (maille, short), chaussures un peu plus lisses.
			m.roughness = 0.5 if source.resource_name == "Shoes" else (0.7 if source.resource_name == "Sole" else 0.9)
			m.metallic = 0.0
			_materiaux[cle] = m
		corps.set_surface_override_material(i, _materiaux[cle])


static func vider_palette() -> void:
	for cle: String in _materiaux.keys():
		if cle.begins_with("tenue|"):
			_materiaux.erase(cle)
