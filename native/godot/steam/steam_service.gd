extends RefCounted
## Emplacement prévu pour Steamworks (succès et sauvegardes cloud), inactif tant que non configuré.
##
## Activation (à faire après création de l'application Steam par Léo, voir docs/steam/README.md) :
## 1. placer l'extension GodotSteam (GDExtension, sous licence MIT) dans res://addons/godotsteam/ ;
## 2. renseigner app_id et passer enabled à true dans res://steam/steam.json ;
## 3. activer achievements et/ou cloud_saves séparément.
## Sans extension, sans App ID ou avec enabled=false, chaque appel ne fait rien et le jeu reste hors ligne.
##
## Exemple :
##   const Steam = preload("res://steam/steam_service.gd")
##   Steam.unlock_achievement("PREMIER_TITRE")  # sans effet tant que Steam est inactif
const CONFIG := "res://steam/steam.json"

static func config() -> Dictionary:
	var defaults := {"enabled": false, "app_id": 0, "achievements": false, "cloud_saves": false}
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

## Débloque un succès déclaré dans Steamworks ; renvoie false si Steam est inactif.
static func unlock_achievement(id: String) -> bool:
	if id.is_empty() or not achievements_enabled(): return false
	var steam := _steam()
	if steam == null or not steam.has_method("setAchievement"): return false
	steam.call("setAchievement", id)
	if steam.has_method("storeStats"): steam.call("storeStats")
	return true
