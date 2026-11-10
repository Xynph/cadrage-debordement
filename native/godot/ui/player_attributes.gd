extends RefCounted

const SUBTITLE := "Notes de simulation sur 100"

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

static func detail(player: Dictionary) -> Dictionary:
	var values: Variant = player.get("attributesV2")
	return values if values is Dictionary and values.size() == 36 else {}

static func caption(value: Variant) -> String:
	if value is int or value is float:
		return str(value).trim_suffix(".0").replace(".", ",")
	return "—"
