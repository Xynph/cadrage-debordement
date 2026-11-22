extends Control
## Anneau chiffré : une valeur sur 100 (condition, moral, confiance…), le chiffre écrit au centre et sa légende dessous.
## Composant partagé (Travail du club, Entraînement › Groupes, Observer la préparation). La couleur double le chiffre,
## elle ne porte jamais seule le signal. Dessiné d'un bloc (aucun enfant) : l'habillage des vues anciennes n'y touche pas.
## Exemple : `parent.add_child(JaugeAnneau.new(86, "Condition moyenne"))`.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")

var valeur := 0.0
var maximum := 100.0
var legende := ""
var couleur := Charte.VERT_CLAIR
## Pictogramme (id de `C.icon_texture`) dessiné à gauche de la légende, de la couleur de l'anneau ; vide = aucun.
var icone := ""
## Unités du gabarit 2560 (mises à l'échelle par C.px).
var diametre := 132.0

func _init(p_valeur: float = 0.0, p_legende: String = "", p_couleur: Color = Charte.VERT_CLAIR, p_maximum: float = 100.0, p_icone: String = "") -> void:
	valeur = p_valeur
	icone = p_icone
	legende = p_legende
	couleur = p_couleur
	maximum = maxf(1.0, p_maximum)
	set_meta("semantic_role", "jauge_anneau")
	set_meta("style_charte", true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "%s : %s / %s" % [legende, _chiffre(valeur), _chiffre(maximum)]
	accessibility_name = tooltip_text
	custom_minimum_size = Vector2(C.px(diametre + 60.0), C.px(diametre + 46.0))

static func _chiffre(x: float) -> String:
	return str(roundi(x))

func _draw() -> void:
	var d := float(C.px(diametre))
	var epaisseur := maxf(3.0, float(C.px(12)))
	var centre := Vector2(size.x * .5, d * .5 + 2.0)
	var rayon := d * .5 - epaisseur * .5
	draw_arc(centre, rayon, 0.0, TAU, 72, Charte.PANNEAU_3, epaisseur, true)
	var part := clampf(valeur / maximum, 0.0, 1.0)
	if part > 0.0:
		draw_arc(centre, rayon, -PI * .5, -PI * .5 + TAU * part, 72, couleur, epaisseur, true)
	var police: Font = C.EXTRA_BOLD
	var corps := maxi(14, C.px(46))
	var texte := _chiffre(valeur)
	var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps).x
	draw_string(police, centre + Vector2(-largeur * .5, corps * .34), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, corps, Charte.IVOIRE)
	var petit := maxi(12, C.px(17))
	var sur := "/ " + _chiffre(maximum)
	var l_sur := C.DISPLAY.get_string_size(sur, HORIZONTAL_ALIGNMENT_LEFT, -1, petit).x
	draw_string(C.DISPLAY, centre + Vector2(-l_sur * .5, corps * .34 + petit + 1.0), sur, HORIZONTAL_ALIGNMENT_LEFT, -1, petit, Charte.IVOIRE_3)
	var corps_legende := maxi(12, C.px(20))
	var mot := legende.to_upper()
	var base := Vector2(0, d + 8.0 + corps_legende)
	if icone.is_empty():
		draw_string(C.BOLD, base, mot, HORIZONTAL_ALIGNMENT_CENTER, size.x, corps_legende, Charte.IVOIRE_2)
		return
	var cote := float(corps_legende) + 4.0
	var l_mot := C.BOLD.get_string_size(mot, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_legende).x
	var ecart := 6.0
	var x0 := (size.x - (cote + ecart + l_mot)) * .5
	draw_texture_rect(C.icon_texture(icone, couleur), Rect2(x0, base.y - cote + 3.0, cote, cote), false)
	draw_string(C.BOLD, Vector2(x0 + cote + ecart, base.y), mot, HORIZONTAL_ALIGNMENT_LEFT, -1, corps_legende, Charte.IVOIRE_2)
