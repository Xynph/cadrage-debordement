extends RefCounted
## Banque d'images du jeu (art/banque, manifeste banque-images.json produit par
## tools/banque-images/integrer.py). Choisit l'image d'un écran selon des critères (météo, moment,
## résultat, phase, niveau d'infrastructure, poste…) et retombe sur l'image neutre de repli.
##
##   var id := BanqueImages.choisir("vestiaire", {"phase": "post", "resultat": "victoire"})
##   var tex := BanqueImages.texture(id)

const DOSSIER = "res://art/banque/"
const MANIFESTE = DOSSIER + "banque-images.json"

static var _images: Dictionary = {}
static var _textures: Dictionary = {}
static var _charge := false

static func _charger() -> void:
	if _charge: return
	_charge = true
	if not FileAccess.file_exists(MANIFESTE): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFESTE))
	if not data is Dictionary: return
	for image: Variant in data.get("images", []):
		if image is Dictionary and image.has("id"): _images[str(image.id)] = image

static func existe(id: String) -> bool:
	_charger()
	return _images.has(id)

static func info(id: String) -> Dictionary:
	_charger()
	return _images.get(id, {})

## Texture de l'image (mise en cache) ; suit la chaîne de repli si le fichier manque ; null si inconnue.
static func texture(id: String) -> Texture2D:
	_charger()
	var vu := {}
	while not id.is_empty() and not vu.has(id):
		vu[id] = true
		if _textures.has(id): return _textures[id]
		var image: Dictionary = _images.get(id, {})
		if image.is_empty(): return null
		var tex := _lire(DOSSIER + str(image.fichier))
		if tex != null:
			_textures[id] = tex
			return tex
		id = str(image.get("repli", ""))
	return null

static func _lire(path: String) -> Texture2D:
	if ResourceLoader.exists(path): return load(path)
	# Jeu exporté sans import du .webp, ou dossier ajouté après l'import : lecture directe.
	if not FileAccess.file_exists(path): return null
	var image := Image.new()
	if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: return null
	return ImageTexture.create_from_image(image)

## Meilleure image pour `ecran` (étiquette `ecrans`) selon `criteres` ; "" si l'écran n'a aucune image.
## Un critère demandé et contredit élimine l'image ; un critère satisfait rapporte un point ; une image sans
## étiquette pour ce critère reste possible (image neutre). À égalité, l'ordre du manifeste départage,
## sauf `graine` (entier) qui fait tourner entre les ex æquo — même graine, même image.
static func choisir(ecran: String, criteres: Dictionary = {}, graine: int = -1) -> String:
	_charger()
	var meilleurs: Array[String] = []
	var meilleur := -1
	for id: String in _images:
		var et: Dictionary = _images[id].get("etiquettes", {})
		if not ecran in et.get("ecrans", []): continue
		var score := 0
		var ecarte := false
		for cle: String in criteres:
			var voulu: Variant = criteres[cle]
			if voulu == null or str(voulu).is_empty() or not et.has(cle): continue
			if _egal(et[cle], voulu): score += 2
			elif str(et[cle]) == "neutre": score += 0
			else: ecarte = true; break
		if ecarte: continue
		if score > meilleur: meilleur = score; meilleurs = [id]
		elif score == meilleur: meilleurs.append(id)
	if meilleurs.is_empty(): return ""
	return meilleurs[posmod(graine, meilleurs.size())] if graine >= 0 else meilleurs[0]

static func _egal(a: Variant, b: Variant) -> bool:
	if a is Array: return b in a or str(b) in a
	if (a is int or a is float) and (b is int or b is float): return int(a) == int(b)
	return str(a) == str(b)

## Moment de la journée d'un coup d'envoi « HH:MM » à une date ISO : jour, soir ou nuit.
## La nuit tombe plus tôt de novembre à février.
static func moment(heure_locale: Variant, date_iso: Variant = "") -> String:
	var texte := str(heure_locale) if heure_locale is String else ""
	if texte.length() < 4 or not texte.substr(0, 2).is_valid_int(): return ""
	var h := float(int(texte.substr(0, 2))) + float(int(texte.substr(3, 2))) / 60.0
	var parts := str(date_iso).split("-")
	var mois := int(parts[1]) if parts.size() == 3 and parts[1].is_valid_int() else 9
	var hiver := mois in [11, 12, 1, 2]
	var soir := 15.5 if hiver else 17.5
	var nuit := 17.5 if hiver else 20.0
	if h >= nuit or h < 6.0: return "nuit"
	if h >= soir: return "soir"
	return "jour"

## Météo du moteur (`meteo` : pluie 0-2, vent, chaleur) ramenée aux étiquettes de la banque.
static func meteo(m: Variant) -> String:
	if not m is Dictionary: return ""
	if int(m.get("pluie", 0)) > 0: return "pluie"
	return "sec"

## Résultat vu d'un camp à partir d'un score [domicile, extérieur].
static func resultat(score: Variant, camp: int) -> String:
	if not score is Array or score.size() != 2 or camp < 0 or camp > 1: return ""
	var nous := int(score[camp])
	var eux := int(score[1 - camp])
	return "victoire" if nous > eux else ("defaite" if nous < eux else "nul")

## Niveau d'un stade (1 à 5) d'après sa capacité ; 0 si inconnue. 1-4 : stades de club, de la tribune unique
## aux quatre tribunes ; 5 : grande enceinte (20 000 places et plus, Top 14 et grands clubs).
static func niveau_stade(capacite: Variant) -> int:
	if not (capacite is int or capacite is float) or capacite <= 0: return 0
	if capacite < 4000: return 1
	if capacite < 8000: return 2
	if capacite < 12000: return 3
	if capacite < 20000: return 4
	return 5

## Paysage régional d'un club (`sol-*`) d'après son pays et, en France, sa ville ; "" sans correspondance.
## Deux variantes quand la banque en a (v1, v2) : le club garde toujours la même.
const _VILLES_FR := {
	"sud-ouest": ["toulouse", "bordeaux", "la rochelle", "pau", "bayonne", "castres", "biarritz", "brive", "colomiers", "agen", "angouleme", "aurillac", "dax", "montauban", "mont-de-marsan", "tarbes", "auch", "perigueux", "soyaux"],
	"mediterranee": ["toulon", "montpellier", "perpignan", "beziers", "nice", "aix", "narbonne", "carcassonne", "marseille", "nimes", "hyeres", "provence"],
	"est": ["clermont", "lyon", "grenoble", "oyonnax", "valence", "nevers", "bourgoin", "chambery", "dijon", "nancy", "strasbourg", "macon", "bourg-en-bresse", "vienne"],
	"nord": ["paris", "nanterre", "massy", "vannes", "rouen", "lille", "rennes", "nantes", "orleans", "tours", "caen", "chartres", "le havre"]}
const _PAYS := {"GB": "iles-britanniques", "EN": "iles-britanniques", "SC": "iles-britanniques", "WA": "iles-britanniques", "IE": "irlande", "IT": "italie",
	"ZA": "hemisphere-sud-vert", "NZ": "hemisphere-sud-vert", "AU": "hemisphere-sud-vert", "FJ": "hemisphere-sud-vert", "SA": "hemisphere-sud-vert", "WS": "hemisphere-sud-vert", "TO": "hemisphere-sud-vert",
	"AR": "argentine", "UY": "argentine", "CL": "argentine", "GE": "georgie-roumanie", "RO": "georgie-roumanie", "PT": "georgie-roumanie", "ES": "mediterranee"}

static func region(identite: Dictionary) -> String:
	var pays := str(identite.get("country", "")).to_upper()
	var nom := ""
	if pays == "FR":
		var ville := str(identite.get("city", "")).to_lower().replace("é", "e").replace("è", "e").replace("ê", "e").replace("ô", "o")
		for cle: String in _VILLES_FR:
			for v: String in _VILLES_FR[cle]:
				if ville.begins_with(v): nom = cle
		if nom.is_empty() and not ville.is_empty(): nom = "sud-ouest"
	else: nom = str(_PAYS.get(pays, ""))
	if nom.is_empty(): return ""
	var ids: Array[String] = []
	for id: String in ["sol-" + nom, "sol-" + nom + "-v2"]:
		if existe(id): ids.append(id)
	if ids.is_empty(): return ""
	return ids[absi(hash(str(identite.get("slug", identite.get("name", ""))))) % ids.size()]

## Type de compétition d'après l'identifiant de la ligue (photo de la compétition).
static func type_competition(id: String, phase: String = "") -> String:
	var x := id.to_lower()
	if phase == "final": return "finale"
	if phase in ["semi", "quarter", "barrage", "playoff"]: return "barrages"
	if "world" in x or "rwc" in x or "coupe-du-monde" in x: return "coupe-du-monde"
	if "nation" in x or "six" in x or "tournoi" in x or "rugby-championship" in x or "test" in x: return "tournoi-nations"
	if "epcr" in x or "europ" in x or "champions" in x or "challenge" in x: return "coupe-europe"
	if "cup" in x or "coupe" in x: return "coupe-nationale"
	return "championnat"

## Niveau 1 à 4 du centre d'entraînement d'après le niveau des installations (0 à 10) ; 0 si inconnu.
static func niveau_centre(niveau: Variant) -> int:
	if not (niveau is int or niveau is float): return 0
	return clampi(1 + int(niveau) / 3, 1, 4)

## En-tête d'un courrier selon son thème (texte du message) ; "" : rien de propre au thème.
static func courrier(texte: String) -> String:
	var f := texte.to_lower()
	for paire: Array in [[["tresorerie", "trésorerie", "budget", "finances", "billetterie", "recettes"], "mail-finances"], [["sponsor", "partenaire", "mécène"], "mail-sponsor"],
			[["presse", "journal", "rumeur", "rubrique", "conférence", "polémique"], "mail-presse-polemique"], [["supporters", "abonnés", "tribunes"], "mail-supporters"],
			[["suspension", "commission", "discipline", "carton"], "mail-discipline"], [["sélection", "convocation", "international"], "mail-selection-nationale"],
			[["transfert", "recrue", "signé", "signe", "arrivée"], "mail-transfert-signe"], [["blessure", "blessé", "indisponib", "opér"], "mail-blessure-grave"],
			[["contrat", "prolongation", "salaire"], "mail-contrat"], [["espoir", "formation", "jeune", "crabos"], "mail-jeunes"],
			[["météo", "vent", "pluie", "orage", "chaleur"], "mail-meteo-alerte"], [["trêve", "vacances", "repos"], "mail-calendrier-treve"],
			[["anniversaire", "histoire du club", "centenaire"], "mail-anniversaire-club"], [["derby", "rival"], "mail-rivalite"]]:
		for mot: String in paire[0]:
			if mot in f: return paire[1] if existe(paire[1]) else ""
	return ""
