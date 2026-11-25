extends RefCounted
const Knowledge = preload("res://ui/player_knowledge_text.gd")

const SUBTITLE := "Notes de simulation sur 100"
const GENERATED_ID_PREFIX := "depth-"
const GENERATED_TITLE := "Joueur généré pour compléter l’effectif"

## Les joueurs « depth-… » sont créés par le moteur pour tenir le plancher de
## quarante professionnels ; ils n’ont aucun dossier de référence externe.
static func is_generated(player: Dictionary) -> bool:
	return str(player.get("id", "")).begins_with(GENERATED_ID_PREFIX)

# Clés du registre attributesV2. Ces groupes organisent seulement la lecture.
const GROUPS = [
	["Ballon et jeu au pied", [
		["passing", "Passe"], ["receiving", "Réception"], ["offload", "Passe après contact"],
		["ballCarry", "Portage du ballon"], ["evasion", "Évitement"], ["ballHandling", "Maniement du ballon"],
		["kickDistance", "Distance au pied"], ["kickAccuracy", "Précision au pied"], ["goalAccuracy", "Précision au but"],
	]],
	["Lecture et collectif", [
		["decisions", "Prise de décision"], ["anticipation", "Anticipation"], ["vision", "Vision du jeu"],
		["positioning", "Placement"], ["composure", "Sang-froid"], ["discipline", "Discipline"],
		["teamwork", "Jeu collectif"], ["leadership", "Leadership"], ["workRate", "Activité"],
	]],
	["Physique et jeu aérien", [
		["acceleration", "Accélération"], ["topSpeed", "Vitesse de pointe"], ["agility", "Agilité"],
		["explosiveness", "Explosivité"], ["strength", "Force"], ["endurance", "Endurance"],
		["jumping", "Détente"], ["kickChase", "Chasse au coup de pied"], ["aerialAbility", "Jeu aérien"],
	]],
	["Défense et conquête", [
		["tackling", "Plaquage"], ["jackal", "Grattage"], ["ruckClearout", "Nettoyage de ruck"],
		["scrumTechnique", "Technique de mêlée"], ["hooking", "Talonnage"], ["lineoutThrow", "Lancer en touche"],
		["lineoutJump", "Saut en touche"], ["lineoutLift", "Soutien en touche"], ["maul", "Maul"],
	]],
]

static func detail(player: Dictionary, own_context: bool = false) -> Dictionary:
	if not Knowledge.attributes_known(player,own_context): return {}
	var values: Variant = player.get("attributesV2")
	return values if values is Dictionary and values.size() == 36 else {}

## Qualités en fourchette (option de carrière, player-knowledge.cjs) : {min, max} d'une qualité, {} sinon.
static func plage(player: Dictionary, key: String) -> Dictionary:
	var plages: Variant = player.get("attributesV2Range")
	var p: Variant = plages.get(key) if plages is Dictionary else null
	return p if p is Dictionary and (p.get("min") is int or p.get("min") is float) and (p.get("max") is int or p.get("max") is float) else {}

## Texte d'une qualité d'un joueur : « 45-49 » tant que le staff n'est pas sûr (même format que la fiche), sinon le chiffre.
static func caption_joueur(player: Dictionary, key: String, value: Variant) -> String:
	var p := plage(player, key)
	if not p.is_empty(): return "%d-%d" % [int(p.min), int(p.max)]
	return caption(value)

static func caption(value: Variant) -> String:
	# Le moteur garde les qualités au dixième (progression étalée, #1196) : l'écran n'affiche que l'entier.
	if value is int or value is float: return str(roundi(float(value)))
	return "—"
