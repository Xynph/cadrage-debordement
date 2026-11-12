extends RefCounted
## Composants communs aux trois rendus du nouvel entracte (tableau de bord, carnet du coach,
## régie TV), où le terrain 2D est petit et le reste porte les informations du manager :
## jauge d'énergie horizontale, pastille de note, tuile titrée et ligne de données d'un joueur
## bornée à ce qui a déjà été montré (notes du moteur : note, faits, essais, mètres ; le moteur
## ne compte pas les plaquages joueur par joueur).

const T = preload("res://theme.gd")
const CHIFFRES = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")

const FOND := Color("0b1012")
const PANNEAU := Color("121a1c")
const TRAIT := Color("232f2e")
const IVOIRE := Color("f2ecdc")
const FAIBLE := Color("7b8a84")
const OR := Color("e0b35a")
const VERT := Color("65b081")
const ALERTE := Color("e2876f")
const FATIGUE := 55.0
const SURVEILLE := 70.0

## Teintes partagées : énergie (mêmes seuils que l'anneau de Mon XV : 70 à surveiller,
## 55 fatigue) et note de match (7 et plus bon, sous 6 en alerte).
class Teintes:
	static func energie(v: float) -> Color:
		return VERT if v >= SURVEILLE else (OR if v >= FATIGUE else ALERTE)

	static func note(n: float) -> Color:
		return VERT if n >= 7.0 else (OR if n >= 6.0 else ALERTE)

## Jauge d'énergie horizontale (0 à 100) avec la valeur à droite.
class Jauge extends Control:
	var valeur := 100.0
	var densite := 0.5
	var chiffre := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var corps := roundi(maxf(11.0, 24.0 * densite))
		var place: float = CHIFFRES.get_string_size("100", HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x + 6.0 if chiffre else 0.0
		var h := maxf(4.0, 10.0 * densite)
		var y := (size.y - h) * 0.5
		var largeur := maxf(0.0, size.x - place)
		var teinte: Color = Teintes.energie(valeur)
		draw_rect(Rect2(0, y, largeur, h), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(0, y, largeur * clampf(valeur / 100.0, 0.0, 1.0), h), teinte)
		if chiffre:
			var texte := str(roundi(valeur))
			draw_string(CHIFFRES, Vector2(size.x - CHIFFRES.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x, size.y * 0.5 + corps * 0.36), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, teinte)

## Note du match dans une pastille teintée (fond à 25 %, chiffre plein).
class Note extends Control:
	var valeur := 6.0
	var densite := 0.5

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var teinte: Color = Teintes.note(valeur)
		draw_style_box(T.box(Color(teinte, 0.22), maxi(3, roundi(8.0 * densite))), Rect2(Vector2.ZERO, size))
		var corps := roundi(maxf(12.0, 26.0 * densite))
		var texte := ("%.1f" % valeur).replace(".", ",")
		var largeur: float = CHIFFRES.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
		draw_string(CHIFFRES, Vector2((size.x - largeur) * 0.5, size.y * 0.5 + corps * 0.36), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, teinte)

## Données d'un joueur pour une ligne de Mon XV, bornées à l'entracte : énergie (condition),
## note, faits, essais et mètres du moteur, carton et blessure montrés. Rien sur l'action à venir.
static func donnees_joueur(joueur: Variant, notes: Dictionary, cartons: Dictionary) -> Dictionary:
	if not joueur is Dictionary: return {"vacant": true}
	var id := str(joueur.get("id", ""))
	var note: Dictionary = notes.get(id, {}) if notes.get(id) is Dictionary else {}
	var carton: Dictionary = cartons.get(id, {}) if cartons.get(id) is Dictionary else {}
	return {
		"vacant": false,
		"id": id,
		"nom": str(joueur.get("name", "")),
		"poste": str(joueur.get("pos", "")),
		"blesse": int(joueur.get("injury", 0)) > 0,
		"energie": float(joueur.get("condition", 100)),
		"note": float(note.get("note", 6.0)),
		"faits": int(note.get("faits", 0)),
		"essais": int(note.get("essais", 0)),
		"metres": roundi(float(note.get("metres", 0))),
		"plaquages": int(note.get("plaquages", 0)),
		"carton": not carton.is_empty(),
		"retour": carton.get("retour"),
	}

## Numéro d'un joueur dans un disque aux couleurs du club (comme sur le terrain), avec une
## pastille en haut à droite pour une blessure ou un carton.
class Numero extends Control:
	var numero := ""
	var teinte := VERT
	var densite := 0.5
	var marque := Color.TRANSPARENT

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		r = minf(r, 20.0 * densite * 1.15)
		draw_circle(c, r + maxf(1.0, 2.0 * densite), FOND)
		draw_circle(c, r, teinte)
		var corps := roundi(maxf(11.0, r * 1.15))
		var largeur: float = CHIFFRES.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
		draw_string(CHIFFRES, c + Vector2(-largeur * 0.5, corps * 0.36), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, IVOIRE)
		if marque.a > 0.0: draw_circle(c + Vector2(r, -r) * 0.75, maxf(3.0, 6.0 * densite), marque)
