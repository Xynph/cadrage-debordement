extends Control
## Barre d'effet de part et d'autre d'un axe central : gain vers la droite (plein), perte vers la gauche (hachurée), le
## chiffre et son sujet écrits au bout (« +3 moral », « −1 confiance »). Toutes les barres d'un même graphique partagent
## `echelle` (plus grand écart absolu) pour rester comparables. Avec `entete`, dessine seulement l'axe et « ◀ PERTE · GAIN ▶ ».
## Composant partagé (Travail du club, Entraînement › Groupes). Exemple : `BarreEffet.new(3, "moral", 5)`.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")

var ecart := 0.0
var sujet := ""
var echelle := 5.0
var entete := false
var couleur := Charte.VERT_CLAIR

func _init(p_ecart: float = 0.0, p_sujet: String = "", p_echelle: float = 5.0, p_entete: bool = false) -> void:
	ecart = p_ecart
	sujet = p_sujet
	echelle = maxf(1.0, p_echelle)
	entete = p_entete
	set_meta("semantic_role", "barre_effet")
	set_meta("style_charte", true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(C.px(300), C.px(24 if entete else 34))
	if not entete:
		tooltip_text = "%s %s" % [texte(), sujet]
		accessibility_name = tooltip_text

func texte() -> String:
	var e := roundi(ecart)
	if e > 0: return "+%d" % e
	if e < 0: return "−%d" % absi(e)
	return "="

func _draw() -> void:
	var milieu := size.x * .5
	var corps := maxi(12, C.px(20))
	if entete:
		draw_string(C.BOLD, Vector2(0, size.y - 4.0), "◀ PERTE", HORIZONTAL_ALIGNMENT_RIGHT, milieu - C.px(12), corps, Charte.IVOIRE_3)
		draw_string(C.BOLD, Vector2(milieu + C.px(12), size.y - 4.0), "GAIN ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, corps, Charte.IVOIRE_3)
		draw_line(Vector2(milieu, 0), Vector2(milieu, size.y), Charte.IVOIRE_3, 1.0)
		return
	draw_line(Vector2(milieu, 0), Vector2(milieu, size.y), Charte.IVOIRE_3, 1.0)
	# La place du texte (« −10 confiance ») est réservée de chaque côté : la barre n'empiète jamais dessus.
	var gros := maxi(13, C.px(23))
	var etiquette := "%s %s" % [texte(), sujet]
	var l_texte := C.BOLD.get_string_size(etiquette, HORIZONTAL_ALIGNMENT_LEFT, -1, gros).x
	var portee := maxf(8.0, milieu - l_texte - C.px(16))
	var longueur := clampf(absf(ecart) / echelle, 0.0, 1.0) * portee
	var h := maxf(6.0, float(C.px(16)))
	var y := (size.y - h) * .5
	var base := y + h * .5 + gros * .36
	if ecart > 0.0:
		draw_rect(Rect2(milieu, y, longueur, h), couleur)
		draw_string(C.BOLD, Vector2(milieu + longueur + C.px(10), base), etiquette, HORIZONTAL_ALIGNMENT_LEFT, -1, gros, Charte.IVOIRE)
	elif ecart < 0.0:
		var r := Rect2(milieu - longueur, y, longueur, h)
		draw_rect(r, Color(Charte.IVOIRE_3, .25))
		var pas := maxf(4.0, float(C.px(8)))
		var x := r.position.x - h
		while x < r.end.x:
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + h, r.end.x)
			if x1 > x0: draw_line(Vector2(x0, y + h - (x0 - x)), Vector2(x1, y + h - (x1 - x)), Charte.IVOIRE_2, 1.5, true)
			x += pas
		draw_rect(r, Charte.IVOIRE_2, false, 1.0)
		draw_string(C.BOLD, Vector2(r.position.x - C.px(10) - l_texte, base), etiquette, HORIZONTAL_ALIGNMENT_LEFT, -1, gros, Charte.IVOIRE)
	else:
		draw_circle(Vector2(milieu, y + h * .5), h * .35, Charte.IVOIRE_3)
		draw_string(C.BOLD, Vector2(milieu + C.px(12), base), "= %s" % sujet, HORIZONTAL_ALIGNMENT_LEFT, -1, gros, Charte.IVOIRE_2)
