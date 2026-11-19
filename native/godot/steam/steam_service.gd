extends RefCounted
## Emplacement prévu pour Steamworks (succès et sauvegardes cloud), inactif tant que non configuré.
##
## Activation (à faire après création de l'application Steam par Léo, voir docs/steam/README.md) :
## 1. placer l'extension GodotSteam (GDExtension, sous licence MIT) dans res://addons/godotsteam/ ;
## 2. renseigner app_id et passer enabled à true dans res://steam/steam.json ;
## 3. activer achievements, cloud_saves et/ou workshop séparément.
## Sans extension, sans App ID ou avec enabled=false, chaque appel ne fait rien et le jeu reste hors ligne.
##
## Exemple :
##   const Steam = preload("res://steam/steam_service.gd")
##   Steam.unlock_achievement("PREMIER_TITRE")  # sans effet tant que Steam est inactif
const CONFIG := "res://steam/steam.json"

static func config() -> Dictionary:
	var defaults := {"enabled": false, "app_id": 0, "achievements": false, "cloud_saves": false, "workshop": false}
	var file := FileAccess.open(CONFIG, FileAccess.READ)
	if file == null: return defaults
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return defaults
	for key in defaults:
		if parsed.has(key): defaults[key] = parsed[key]
	return defaults

## Vrai seulement si la configuration est activée, l'App ID renseigné et l'extension GodotSteam chargée.
static func available() -> bool:
	var settings := config()
	return bool(settings.enabled) and int(settings.app_id) > 0 and Engine.has_singleton("Steam")

static func _steam() -> Object:
	return Engine.get_singleton("Steam") if available() else null

static func achievements_enabled() -> bool:
	return available() and bool(config().achievements)

static func cloud_saves_enabled() -> bool:
	return available() and bool(config().cloud_saves)

static func workshop_enabled() -> bool:
	return available() and bool(config().workshop)

## Packs de données du Steam Workshop déjà téléchargés par Steam (abonnements du joueur).
## Un objet Workshop contient un ou plusieurs ZIP au format des packs d'identités (pack.json à la racine,
## voir docs/steam/README.md § Workshop) ; le jeu ne lit que ces ZIP et les confie au moteur, qui les valide
## comme un import manuel. Le jeu de base n'embarque jamais de données réelles : elles n'arrivent que par ce canal.
## Renvoie [{item_id, title, path}] ; vide tant que Steam ou le Workshop sont inactifs.
static func workshop_packs() -> Array:
	var packs: Array = []
	if not workshop_enabled(): return packs
	var steam := _steam()
	if steam == null or not steam.has_method("getSubscribedItems") or not steam.has_method("getItemInstallInfo"): return packs
	for item_id in steam.call("getSubscribedItems"):
		var info: Variant = steam.call("getItemInstallInfo", item_id)
		if not info is Dictionary or not bool(info.get("ret", false)): continue
		packs.append_array(zip_packs_in(str(info.get("folder", "")), int(item_id)))
	return packs

## ZIP de premier niveau d'un dossier d'objet Workshop (aucun parcours récursif, aucun lien suivi).
static func zip_packs_in(folder: String, item_id: int) -> Array:
	var found: Array = []
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder): return found
	for file in DirAccess.get_files_at(folder):
		if file.get_extension().to_lower() == "zip":
			found.append({"item_id": item_id, "title": file.get_basename(), "path": folder.path_join(file)})
	return found

## Débloque un succès déclaré dans Steamworks ; renvoie false si Steam est inactif.
static func unlock_achievement(id: String) -> bool:
	if id.is_empty() or not achievements_enabled(): return false
	var steam := _steam()
	if steam == null or not steam.has_method("setAchievement"): return false
	steam.call("setAchievement", id)
	if steam.has_method("storeStats"): steam.call("storeStats")
	return true
