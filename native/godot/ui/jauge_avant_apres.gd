extends Control
## Jauge « maintenant → prévu » : la valeur actuelle en plein, l'écart prévu en clair (gain) ou hachuré (perte), un repère
## au niveau prévu ; au-dessus, la légende et les chiffres écrits « 77 → 80 ▲ +3 ». La couleur ne porte jamais seule le
## sens : flèche, signe et chiffres l'écrivent. Composant partagé (Travail du club, Entraînement › Groupes).
## Exemple : `parent.add_child(JaugeAvantApres.new("Moral", 77, 80))`.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")

var legende := ""
var actuel := 0.0
var prevu := 0.0
var maximum := 100.0
var couleur := Charte.VERT_CLAIR
## Sans prévision : jauge d'état seule, chiffre « 86 / 100 », ni écart ni repère.
var simple := false

func _init(p_legende: String = "", p_actuel: float = 0.0, p_prevu: float = 0.0, p_couleur: Color = Charte.VERT_CLAIR, p_maximum: float = 100.0) -> void:
	legende = p_legende
	actuel = p_actuel
	prevu = p_prevu
	couleur = p_couleur
	maximum = maxf(1.0, p_maximum)
	set_meta("semantic_role", "jauge_avant_apres")
	set_meta("style_charte", true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "%s : %d aujourd’hui, %d prévu (%s)" % [legende, roundi(actuel), roundi(prevu), ecart_texte()]
	accessibility_name = tooltip_text
	custom_minimum_size = Vector2(C.px(220), C.px(52))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Hauteur propre : dans une rangée plus haute (anneaux, grand chiffre), la jauge ne s'étire pas.
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func ecart_texte() -> String:
	var e := roundi(prevu) - roundi(actuel)
	if e > 0: return "▲ +%d" % e
	if e < 0: return "▼ −%d" % absi(e)
	return "= 0"

func _draw() -> void:
	var corps := maxi(12, C.px(20))
	var base := float(corps)
	draw_string(C.BOLD, Vector2(0, base), legende.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x * .45, corps, Charte.IVOIRE_2)
	var gros := maxi(13, C.px(23))
	if simple:
		# Jauge d'état seule (pas de prévision) : « 86 / 100 ».
		var seul := "%d / %d" % [roundi(actuel), roundi(maximum)]
		var l_seul := C.EXTRA_BOLD.get_string_size(seul, HORIZONTAL_ALIGNMENT_LEFT, -1, gros).x
		draw_string(C.EXTRA_BOLD, Vector2(size.x - l_seul, base), seul, HORIZONTAL_ALIGNMENT_LEFT, -1, gros, Charte.IVOIRE)
		var hh := maxf(4.0, float(C.px(11)))
		var yy := size.y - hh - 2.0
		_pilule(Rect2(0, yy, size.x, hh), Charte.PANNEAU_3)
		var aa := clampf(actuel / maximum, 0.0, 1.0) * size.x
		if aa > 0.0: _pilule(Rect2(0, yy, aa, hh), couleur)
		return
	var ecart := ecart_texte()
	var l_ecart := C.BOLD.get_string_size(ecart, HORIZONTAL_ALIGNMENT_LEFT, -1, gros).x
	var couleur_ecart := couleur if prevu > actuel else Charte.IVOIRE
	draw_string(C.BOLD, Vector2(size.x - l_ecart, base), ecart, HORIZONTAL_ALIGNMENT_LEFT, -1, gros, couleur_ecart)
	var chiffres := "%d → %d" % [roundi(actuel), roundi(prevu)]
	var l_chiffres := C.EXTRA_BOLD.get_string_size(chiffres, HORIZONTAL_ALIGNMENT_LEFT, -1, gros).x
	draw_string(C.EXTRA_BOLD, Vector2(size.x - l_ecart - C.px(14) - l_chiffres, base), chiffres, HORIZONTAL_ALIGNMENT_LEFT, -1, gros, Charte.IVOIRE)
	# Rail, puis la part sûre (le plus petit des deux), puis l'écart.
	var h := maxf(4.0, float(C.px(11)))
	var y := size.y - h - 2.0
	var w := size.x
	var rail := Rect2(0, y, w, h)
	_pilule(rail, Charte.PANNEAU_3)
	var a := clampf(actuel / maximum, 0.0, 1.0) * w
	var p := clampf(prevu / maximum, 0.0, 1.0) * w
	var sur := minf(a, p)
	if sur > 0.0: _pilule(Rect2(0, y, sur, h), couleur)
	if p > a:
		draw_rect(Rect2(a, y, p - a, h), Color(couleur, .42))
	elif a > p:
		draw_rect(Rect2(p, y, a - p, h), Color(Charte.IVOIRE_3, .25))
		var pas := maxf(4.0, float(C.px(8)))
		var x := p - h
		while x < a:
			var x0 := maxf(x, p)
			var x1 := minf(x + h, a)
			if x1 > x0:
				draw_line(Vector2(x0, y + h - (x0 - x)), Vector2(x1, y + h - (x1 - x)), Charte.IVOIRE_2, 1.5, true)
			x += pas
	# Repère du niveau prévu.
	draw_rect(Rect2(clampf(p - 1.0, 0.0, w - 2.0), y - 4.0, 2.0, h + 8.0), Charte.IVOIRE)

func _pilule(r: Rect2, c: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(int(r.size.y * .5))
	s.anti_aliasing = true
	draw_style_box(s, r)
