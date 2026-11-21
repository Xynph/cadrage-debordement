extends Control
## Barre empilée : répartition d'un total en parts (ex. repos / normal / intensif) en aplats de la palette des charges
## (Charte.REPOS, NORMAL, INTENSIF, ou `couleur` par part), hachures fines sur la 3e part, le chiffre écrit dans chaque
## part assez large et une légende « 17 repos » dessous (aucune part ne se lit à la seule couleur). Composant partagé (Travail du club, Entraînement › Groupes, Observer la préparation).
## Exemple : `BarreEmpilee.new([{"valeur": 17, "libelle": "repos"}, {"valeur": 19, "libelle": "normal"}, {"valeur": 0, "libelle": "intensif"}])`.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")

## Rang des parts (palette des charges) ; la troisième porte des hachures.
const PREMIERE := 0
const DEUXIEME := 1
const HACHURES := 2

var parts: Array = []

func _init(p_parts: Array = []) -> void:
	parts = p_parts
	set_meta("semantic_role", "barre_empilee")
	set_meta("style_charte", true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(C.px(260), C.px(34 + 12 + 26))
	var lignes := PackedStringArray()
	for part: Dictionary in parts: lignes.append("%d %s" % [int(part.get("valeur", 0)), str(part.get("libelle", ""))])
	tooltip_text = " · ".join(lignes)
	accessibility_name = tooltip_text

func _total() -> int:
	var t := 0
	for part: Dictionary in parts: t += maxi(0, int(part.get("valeur", 0)))
	return t

## Couleur d'une part : celle donnée par l'appelant (`couleur`), sinon la palette des charges de la charte
## (repos turquoise, normal vert, intensif orange). La part intensive garde en plus de fines hachures.
func _peindre(r: Rect2, motif: int, couleur: Variant = null) -> void:
	var c: Color = couleur if couleur is Color else [Charte.REPOS, Charte.NORMAL, Charte.INTENSIF][motif]
	draw_rect(r, c)
	if motif == HACHURES:
		var pas := maxf(6.0, float(C.px(12)))
		var x := r.position.x - r.size.y
		while x < r.end.x:
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + r.size.y, r.end.x)
			if x1 > x0: draw_line(Vector2(x0, r.end.y - (x0 - x)), Vector2(x1, r.end.y - (x1 - x)), Color(Charte.ENCRE, .22), 1.5, true)
			x += pas

func _draw() -> void:
	var h := float(C.px(34))
	var total := _total()
	var corps := maxi(13, C.px(22))
	if total <= 0:
		draw_rect(Rect2(0, 0, size.x, h), Charte.PANNEAU_3)
	else:
		var x := 0.0
		for i in parts.size():
			var v := maxi(0, int(parts[i].get("valeur", 0)))
			if v == 0: continue
			var w := size.x * float(v) / float(total)
			var r := Rect2(x, 0, w, h)
			_peindre(r, i % 3, parts[i].get("couleur"))
			var t := str(v)
			var l := C.EXTRA_BOLD.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
			if w >= l + C.px(16):
				draw_string(C.EXTRA_BOLD, Vector2(x + (w - l) * .5, h * .5 + corps * .36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, Charte.ENCRE)
			x += w
			if x < size.x - 1.0: draw_line(Vector2(x, 0), Vector2(x, h), Charte.PANNEAU, 2.0)
	# Légende : pastille au motif de la part + « 17 repos ».
	var y := h + C.px(12)
	var cote := float(C.px(18))
	var lx := 0.0
	var petit := maxi(12, C.px(20))
	for i in parts.size():
		_peindre(Rect2(lx, y + 2.0, cote, cote), i % 3, parts[i].get("couleur"))
		lx += cote + C.px(8)
		var t := "%d %s" % [int(parts[i].get("valeur", 0)), str(parts[i].get("libelle", ""))]
		draw_string(C.BOLD, Vector2(lx, y + cote), t, HORIZONTAL_ALIGNMENT_LEFT, -1, petit, Charte.IVOIRE_2)
		lx += C.BOLD.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, petit).x + C.px(26)
